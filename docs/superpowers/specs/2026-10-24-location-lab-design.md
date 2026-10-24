# Location lab (Phase 0) design

Date: 2026-10-24. Owner decisions in `docs/superpowers/plans/decision-log.md` (2026-10-24). Handoff source: `rast-flutter-handoff/docs/03_FLUTTER_IMPLEMENTATION_PLAN.md` Phase 0, `04_ARCHITECTURE_AND_DATA.md` §4.

## Goal

Measure, on the owner's real phones, whether a Flutter app can deliver location samples every 15 to 120 seconds in the background with enough accuracy and continuity to detect a crossing of at most 20 metres between two people. Produce numbers, not opinions, so the owner can accept or reject the premise before Phase 5.

## Non-goals

- No server, no accounts, no upload. All data stays on the device until the tester exports it.
- No product UI, no rast theme, no reuse of `lib/`. The lab is a separate Flutter project in `labs/location_lab/` and is never shipped.
- No decision on numeric thresholds in code. The analysis prints sensitivity tables; the owner picks.

## Questions the lab must answer

1. Observed interval distribution per requested interval (15, 30, 60, 120 s), foreground and background, screen locked, battery saver on and off.
2. Outages: gaps longer than three times the requested interval, when they start, and whether sampling resumes without user action, including after process termination and relaunch.
3. Horizontal accuracy distribution, outdoors and indoors.
4. Sample age: device clock minus fix timestamp, and device clock offset from NTP.
5. Battery drain per hour at each interval.
6. For two phones: with the real distance series and hand-logged ground truth, how often a true crossing is detected and how often a false one appears, for candidate radii and time windows.

## The lab app

Flutter project `labs/location_lab/`, application id `app.rast.locationlab`, Android first (built here), iOS configured for the owner's Mac.

Dependencies: `flutter_riverpod`, `geolocator` 14.x (stream with `AndroidSettings.foregroundNotificationConfig` for a location foreground service; `AppleSettings.allowBackgroundLocationUpdates`), `permission_handler` (background permission), `sqflite` plus `sqflite_common_ffi` for tests, `battery_plus`, `device_info_plus`, `path_provider`, `share_plus`, `ntp`, `uuid`.

### Screens

- **Home.** Permission status row (fine, background, notifications) with a "Fix" button that requests the missing one. Settings: interval chips 15 / 30 / 60 / 120 s, accuracy chips Best / High / Medium, distance filter fixed at 0. Start / Stop button. Live panel: sample count, seconds since last fix, last accuracy in metres, last lifecycle state, battery percent. Marker buttons "Together" and "Apart" for pair tests, plus a free-text note field with "Add note". Event feed (last 20 events).
- **Sessions.** List of past sessions with start time, duration, interval, sample count. Tap to export (share sheet with `session.json`, `samples.csv`, `events.csv`) or delete.

### Recording

One session per Start. Session row: `id` (uuid v4), `device_id` (installation uuid, persisted), `device_model`, `os_version`, `app_version`, `started_at_utc_ms`, `ended_at_utc_ms`, `requested_interval_s`, `requested_accuracy` (`best|high|medium`), `ntp_offset_ms` (NTP minus device clock, measured at start, null when offline), `notes`.

Sample row per position: `session_id`, `seq`, `device_time_utc_ms` (clock when received), `fix_time_utc_ms` (position timestamp), `lat`, `lon`, `accuracy_m`, `altitude_m`, `speed_mps`, `heading_deg`, `is_mocked`, `lifecycle` (`resumed|inactive|paused|hidden|detached`), `battery_pct`, `battery_state` (`charging|discharging|full|unknown`).

Event row: `session_id`, `time_utc_ms`, `kind` (`lifecycle|permission|stream|error|marker|note|battery|app_start`), `detail` (free text; markers use `together` and `apart`).

An `app_start` event is written whenever the app process starts while a session is still open (no `ended_at_utc_ms`), so process deaths show up as `app_start` after a gap. The sampler resumes automatically in that case.

### Export format

`samples.csv` and `events.csv` have a header row and the columns above in that order. `session.json` is the session row. Files are written to the app documents directory under `exports/<session_id>/` and handed to the share sheet; `adb pull` of that path also works.

## Analysis script

`labs/location_lab/tools/analyze.py`, Python 3 standard library only, tests with `unittest`.

- `analyze.py single <export_dir>` prints a Markdown report: requested interval; count; interval median, p90, p99, max; outages (gap > 3 × interval) with start time and length, split by lifecycle state; accuracy median, p90; sample age median, p90; NTP offset; battery drain per hour (linear fit of `battery_pct` over time while `discharging`).
- `analyze.py pair <export_dir_a> <export_dir_b>` aligns both devices on NTP-corrected time, builds a distance series (haversine) by pairing each sample of A with the nearest-in-time sample of B within a window, and reports, for radius in {20, 30, 50} m and window in {30, 60, 120} s: detected crossing intervals, ground-truth intervals from `together`/`apart` markers on either device, recall (ground-truth intervals with at least one detection inside), and false detections (detections outside any ground-truth interval). Also prints the minimum distance per ground-truth interval and the accuracy at that moment.

Distance between two fixes also reports `distance - (accuracy_a + accuracy_b)` as the optimistic bound so the owner sees how much accuracy noise eats the 20 m rule.

## Test protocol

`labs/location_lab/PROTOCOL.md` lists the runs, each 20 minutes unless stated: foreground walking; background, screen locked, walking; background, battery saver on; indoors stationary; two phones walking past each other at 1 to 2 m, five passes, markers at each pass; two phones sitting 5 m apart for 10 minutes; two phones 50 m apart for 10 minutes; force-stop the app mid-session, relaunch, check `app_start`; revoke background permission mid-session. Each run is one session, exported and named `<device>-<run>-<date>`.

## Gate

Phase 0 is done when the owner has seen the `single` reports for Pixel 9a and the second Android phone across the protocol, and the `pair` report for the walking-past runs, and has recorded in the decision log either acceptance of the measured limitations or a change to radius, cadence or detection semantics. iOS runs follow when the owner builds on the Mac; they are not required for the Android decision.
