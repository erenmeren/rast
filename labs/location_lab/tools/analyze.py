#!/usr/bin/env python3
"""Turn rast location lab exports into Markdown reports.

    analyze.py single <export_dir>
    analyze.py pair <export_dir_a> <export_dir_b>

Standard library only. Column names follow
docs/superpowers/specs/2026-10-24-location-lab-design.md.
"""
from __future__ import annotations

import csv
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path

RADII_M = (20, 30, 50)
WINDOWS_S = (30, 60, 120)
OUTAGE_FACTOR = 3

_INT_COLUMNS = {"seq", "device_time_utc_ms", "fix_time_utc_ms", "battery_pct", "time_utc_ms"}
_FLOAT_COLUMNS = {"lat", "lon", "accuracy_m", "altitude_m", "speed_mps", "heading_deg"}
_BOOL_COLUMNS = {"is_mocked"}


@dataclass
class Export:
    session: dict
    samples: list
    events: list


@dataclass
class Outage:
    start_utc_ms: int
    length_s: float
    lifecycle_before: str


# ---------------------------------------------------------------- loading


def _parse_row(row: dict) -> dict:
    out = {}
    for key, value in row.items():
        if key in _INT_COLUMNS:
            out[key] = int(value)
        elif key in _FLOAT_COLUMNS:
            out[key] = float(value)
        elif key in _BOOL_COLUMNS:
            out[key] = value.strip().lower() == "true"
        else:
            out[key] = value
    return out


def _read_csv(path: Path) -> list:
    with path.open(newline="", encoding="utf-8") as fh:
        return [_parse_row(r) for r in csv.DictReader(fh)]


def load_export(path) -> Export:
    p = Path(path)
    session = json.loads((p / "session.json").read_text(encoding="utf-8"))
    samples = sorted(_read_csv(p / "samples.csv"), key=lambda s: s["device_time_utc_ms"])
    events = sorted(_read_csv(p / "events.csv"), key=lambda e: e["time_utc_ms"])
    return Export(session, samples, events)


# ---------------------------------------------------------------- statistics


def intervals(samples) -> list:
    times = [s["device_time_utc_ms"] for s in samples]
    return [(b - a) / 1000.0 for a, b in zip(times, times[1:])]


def percentile(values, p):
    """Nearest-rank percentile; None for an empty list."""
    if not values:
        return None
    ordered = sorted(values)
    rank = max(1, math.ceil(p / 100.0 * len(ordered)))
    return ordered[min(rank, len(ordered)) - 1]


def outages(samples, interval_s) -> list:
    threshold = OUTAGE_FACTOR * interval_s
    result = []
    for before, after in zip(samples, samples[1:]):
        gap = (after["device_time_utc_ms"] - before["device_time_utc_ms"]) / 1000.0
        if gap > threshold:
            result.append(Outage(before["device_time_utc_ms"], gap, before["lifecycle"]))
    return result


def sample_ages(samples) -> list:
    return [(s["device_time_utc_ms"] - s["fix_time_utc_ms"]) / 1000.0 for s in samples]


def battery_drain_per_hour(samples):
    """Positive percent per hour lost while discharging; None when too little data."""
    rows = [s for s in samples if s["battery_state"] == "discharging"]
    if len(rows) < 2:
        return None
    t0 = rows[0]["device_time_utc_ms"]
    xs = [(s["device_time_utc_ms"] - t0) / 3600000.0 for s in rows]
    if xs[-1] - xs[0] < 10 / 60.0:
        return None
    ys = [float(s["battery_pct"]) for s in rows]
    n = len(xs)
    mean_x = sum(xs) / n
    mean_y = sum(ys) / n
    sxx = sum((x - mean_x) ** 2 for x in xs)
    if sxx == 0:
        return None
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys)) / sxx
    return -slope


# ---------------------------------------------------------------- report


def _fmt(value, unit="", digits=1):
    if value is None:
        return "–"
    return f"{value:.{digits}f}{unit}"


def _utc(ms):
    import datetime as dt

    return dt.datetime.fromtimestamp(ms / 1000.0, tz=dt.timezone.utc).strftime("%H:%M:%S")


def single_report(export: Export) -> str:
    s = export.session
    samples = export.samples
    interval_s = int(s["requested_interval_s"])
    iv = intervals(samples)
    ages = sample_ages(samples)
    acc = [x["accuracy_m"] for x in samples]
    outs = outages(samples, interval_s)
    span_min = (
        (samples[-1]["device_time_utc_ms"] - samples[0]["device_time_utc_ms"]) / 60000.0 if len(samples) > 1 else 0.0
    )

    by_state = {}
    for st in ("resumed", "inactive", "paused", "hidden", "detached"):
        rows = [x for x in samples if x["lifecycle"] == st]
        if rows:
            by_state[st] = rows

    lines = [
        f"# Location lab report: {s.get('device_model', '?')} ({s.get('os_version', '?')})",
        "",
        f"- Session `{s.get('id', '?')}`, requested interval **{interval_s} s**, accuracy **{s.get('requested_accuracy', '?')}**",
        f"- Samples: **{len(samples)}** over {_fmt(span_min, ' min')}",
        f"- NTP offset at start: {s.get('ntp_offset_ms', '–')} ms",
        "",
        "## Intervals (s)",
        "",
        "| median | p90 | p99 | max |",
        "| --- | --- | --- | --- |",
        f"| {_fmt(percentile(iv, 50))} | {_fmt(percentile(iv, 90))} | {_fmt(percentile(iv, 99))} | {_fmt(max(iv) if iv else None)} |",
        "",
        f"## Outages (gap > {OUTAGE_FACTOR} × {interval_s} s = {OUTAGE_FACTOR * interval_s} s)",
        "",
    ]
    if outs:
        lines += ["| starts (UTC) | length (s) | state before |", "| --- | --- | --- |"]
        lines += [f"| {_utc(o.start_utc_ms)} | {o.length_s:.0f} | {o.lifecycle_before} |" for o in outs]
    else:
        lines.append("None.")
    lines += [
        "",
        "## Samples by lifecycle state",
        "",
        "| state | samples | interval median (s) | interval p90 (s) |",
        "| --- | --- | --- | --- |",
    ]
    for st, rows in by_state.items():
        siv = intervals(rows)
        lines.append(f"| {st} | {len(rows)} | {_fmt(percentile(siv, 50))} | {_fmt(percentile(siv, 90))} |")
    lines += [
        "",
        "## Accuracy (m)",
        "",
        f"- median {_fmt(percentile(acc, 50))}, p90 {_fmt(percentile(acc, 90))}, worst {_fmt(max(acc) if acc else None)}",
        f"- samples with accuracy ≤ 20 m: {sum(1 for a in acc if a <= 20)} of {len(acc)}",
        "",
        "## Sample age (device clock − fix time, s)",
        "",
        f"- median {_fmt(percentile(ages, 50))}, p90 {_fmt(percentile(ages, 90))}",
        "",
        "## Battery",
        "",
        f"- drain while discharging: {_fmt(battery_drain_per_hour(samples), ' %/h')}",
        "",
        "## Events",
        "",
    ]
    counts = {}
    for e in export.events:
        counts[e["kind"]] = counts.get(e["kind"], 0) + 1
    lines.append(", ".join(f"{k}: {v}" for k, v in sorted(counts.items())) or "None.")
    app_starts = [e for e in export.events if e["kind"] == "app_start"]
    if app_starts:
        lines += ["", "Process restarts (app_start): " + ", ".join(_utc(e["time_utc_ms"]) for e in app_starts)]
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- pair mode


@dataclass
class Pairing:
    t_utc_ms: int
    distance_m: float
    optimistic_m: float
    acc_a: float
    acc_b: float


@dataclass
class Interval:
    start_utc_ms: int
    end_utc_ms: int


@dataclass
class Score:
    recall: object
    false_detections: int
    min_distance_per_truth: list


def haversine_m(lat1, lon1, lat2, lon2) -> float:
    r = 6371008.8
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = p2 - p1
    dlmb = math.radians(lon2 - lon1)
    h = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def corrected_time(sample, session) -> int:
    return sample["device_time_utc_ms"] + int(session.get("ntp_offset_ms") or 0)


def align(a: Export, b: Export, window_s: int) -> list:
    """Pair each sample of A with B's nearest sample in corrected time within window_s."""
    b_rows = sorted(((corrected_time(s, b.session), s) for s in b.samples), key=lambda r: r[0])
    b_times = [t for t, _ in b_rows]
    window_ms = window_s * 1000
    result = []
    import bisect

    for sa in a.samples:
        ta = corrected_time(sa, a.session)
        i = bisect.bisect_left(b_times, ta)
        best = None
        for j in (i - 1, i):
            if 0 <= j < len(b_times):
                dt = abs(b_times[j] - ta)
                if dt <= window_ms and (best is None or dt < best[0]):
                    best = (dt, b_rows[j][1])
        if best is None:
            continue
        sb = best[1]
        d = haversine_m(sa["lat"], sa["lon"], sb["lat"], sb["lon"])
        acc_a, acc_b = float(sa["accuracy_m"]), float(sb["accuracy_m"])
        result.append(Pairing(ta, d, max(0.0, d - (acc_a + acc_b)), acc_a, acc_b))
    return result


def detections(pairings, radius_m) -> list:
    """Consecutive pairings within radius merge into one interval."""
    result = []
    current = None
    for p in pairings:
        inside = p.distance_m <= radius_m
        if inside and current is None:
            current = Interval(p.t_utc_ms, p.t_utc_ms)
        elif inside:
            current.end_utc_ms = p.t_utc_ms
        elif current is not None:
            result.append(current)
            current = None
    if current is not None:
        result.append(current)
    return result


def _session_end(export: Export) -> int:
    end = export.session.get("ended_at_utc_ms")
    if end is not None:
        return int(end)
    times = [corrected_time(s, export.session) for s in export.samples]
    return max(times) if times else int(export.session.get("started_at_utc_ms") or 0)


def ground_truth(a: Export, b: Export) -> list:
    """together/apart markers from either device, in corrected time."""
    marks = []
    for ex in (a, b):
        off = int(ex.session.get("ntp_offset_ms") or 0)
        for e in ex.events:
            if e["kind"] == "marker" and e["detail"] in ("together", "apart"):
                marks.append((e["time_utc_ms"] + off, e["detail"]))
    marks.sort()
    result = []
    open_at = None
    for t, detail in marks:
        if detail == "together" and open_at is None:
            open_at = t
        elif detail == "apart" and open_at is not None:
            result.append(Interval(open_at, t))
            open_at = None
    if open_at is not None:
        result.append(Interval(open_at, max(_session_end(a), _session_end(b))))
    return result


def _overlaps(x: Interval, y: Interval) -> bool:
    return x.start_utc_ms <= y.end_utc_ms and y.start_utc_ms <= x.end_utc_ms


def score(found, truth, pairings=None) -> Score:
    hits = sum(1 for t in truth if any(_overlaps(d, t) for d in found))
    recall = hits / len(truth) if truth else None
    false = sum(1 for d in found if not any(_overlaps(d, t) for t in truth))
    mins = []
    for t in truth:
        inside = [p.distance_m for p in (pairings or []) if t.start_utc_ms <= p.t_utc_ms <= t.end_utc_ms]
        mins.append(min(inside) if inside else None)
    return Score(recall, false, mins)


def pair_report(a: Export, b: Export) -> str:
    sa, sb = a.session, b.session
    truth = ground_truth(a, b)
    lines = [
        f"# Pair report: {sa.get('device_model', 'A')} vs {sb.get('device_model', 'B')}",
        "",
        f"- A: `{sa.get('id', '?')}`, {len(a.samples)} samples, NTP offset {sa.get('ntp_offset_ms', '–')} ms",
        f"- B: `{sb.get('id', '?')}`, {len(b.samples)} samples, NTP offset {sb.get('ntp_offset_ms', '–')} ms",
        f"- Ground-truth intervals (together → apart): {len(truth)}",
        "",
        "## Sensitivity",
        "",
        "| radius (m) | window (s) | pairings | detections | recall | false detections |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for radius in RADII_M:
        for window in WINDOWS_S:
            pairs = align(a, b, window)
            found = detections(pairs, radius)
            sc = score(found, truth, pairs)
            recall = "–" if sc.recall is None else f"{sc.recall:.2f}"
            lines.append(f"| {radius} | {window} | {len(pairs)} | {len(found)} | {recall} | {sc.false_detections} |")
    lines += ["", "## Ground truth, closest approach (window 60 s)", ""]
    if truth:
        pairs = align(a, b, 60)
        sc = score(detections(pairs, RADII_M[0]), truth, pairs)
        lines += ["| together (UTC) | apart (UTC) | min distance (m) | optimistic (m) | acc A + B (m) |", "| --- | --- | --- | --- | --- |"]
        for t, dmin in zip(truth, sc.min_distance_per_truth):
            inside = [p for p in pairs if t.start_utc_ms <= p.t_utc_ms <= t.end_utc_ms]
            best = min(inside, key=lambda p: p.distance_m) if inside else None
            opt = _fmt(best.optimistic_m) if best else "–"
            acc = _fmt(best.acc_a + best.acc_b) if best else "–"
            lines.append(f"| {_utc(t.start_utc_ms)} | {_utc(t.end_utc_ms)} | {_fmt(dmin)} | {opt} | {acc} |")
    else:
        lines.append("No markers found on either device.")
    lines += [
        "",
        "Optimistic distance = distance − (accuracy A + accuracy B), floored at 0: how much GPS noise could be hiding a real crossing.",
    ]
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------- cli


def main(argv) -> int:
    if len(argv) >= 3 and argv[1] == "single":
        print(single_report(load_export(argv[2])), end="")
        return 0
    if len(argv) >= 4 and argv[1] == "pair":
        print(pair_report(load_export(argv[2]), load_export(argv[3])), end="")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
