import unittest

import analyze
from test_analyze_single import SESSION, mk


def export(samples, events=(), ntp_offset_ms=0, started=0, ended=1000000):
    session = dict(SESSION, ntp_offset_ms=ntp_offset_ms, started_at_utc_ms=started, ended_at_utc_ms=ended)
    return analyze.Export(session, list(samples), list(events))


def marker(t_ms, detail):
    return {"session_id": "s", "time_utc_ms": t_ms, "kind": "marker", "detail": detail}


# Roughly 1 metre of latitude at any longitude.
LAT_M = 1 / 111320.0


class GeometryTests(unittest.TestCase):
    def test_haversine_known_distance(self):
        d = analyze.haversine_m(41.0082, 28.9784, 41.0084, 28.9784)
        self.assertAlmostEqual(d, 22.2, delta=0.5)


class AlignmentTests(unittest.TestCase):
    def test_alignment_applies_ntp_offsets(self):
        # B's clock runs 15 s ahead of true time, so its NTP offset is -15 s.
        a = export([mk(100000), mk(130000)])
        b = export([mk(115000), mk(145000)], ntp_offset_ms=-15000)
        pairs = analyze.align(a, b, window_s=10)
        self.assertEqual(len(pairs), 2)
        self.assertEqual([p.t_utc_ms for p in pairs], [100000, 130000])
        self.assertAlmostEqual(pairs[0].distance_m, 0.0, places=3)

        # Same rows with the offset ignored: every sample is 15 s off, outside the window.
        unaligned = export([mk(115000), mk(145000)], ntp_offset_ms=0)
        self.assertEqual(analyze.align(a, unaligned, window_s=10), [])

    def test_pairing_reports_optimistic_distance(self):
        a = export([mk(0, lat=41.0, acc=10.0)])
        b = export([mk(0, lat=41.0 + 30 * LAT_M, acc=15.0)])
        (p,) = analyze.align(a, b, window_s=30)
        self.assertAlmostEqual(p.distance_m, 30.0, delta=0.2)
        self.assertAlmostEqual(p.optimistic_m, 5.0, delta=0.2)
        self.assertEqual((p.acc_a, p.acc_b), (10.0, 15.0))


class DetectionTests(unittest.TestCase):
    def test_detections_merge_consecutive(self):
        pairs = [
            analyze.Pairing(t, d, d, 5.0, 5.0)
            for t, d in [(0, 50), (30000, 10), (60000, 10), (90000, 50), (120000, 10)]
        ]
        found = analyze.detections(pairs, radius_m=20)
        self.assertEqual([(i.start_utc_ms, i.end_utc_ms) for i in found], [(30000, 60000), (120000, 120000)])


class GroundTruthTests(unittest.TestCase):
    def test_ground_truth_from_one_device_only(self):
        a = export([], events=[marker(100000, "together"), marker(200000, "apart")])
        b = export([])
        truth = analyze.ground_truth(a, b)
        self.assertEqual([(i.start_utc_ms, i.end_utc_ms) for i in truth], [(100000, 200000)])

    def test_unclosed_interval_ends_at_later_session_end(self):
        a = export([], events=[marker(100000, "together")], ended=500000)
        b = export([], ended=700000)
        truth = analyze.ground_truth(a, b)
        self.assertEqual([(i.start_utc_ms, i.end_utc_ms) for i in truth], [(100000, 700000)])


class ScoreTests(unittest.TestCase):
    def test_score_recall_and_false(self):
        truth = [analyze.Interval(100, 200)]
        found = [analyze.Interval(120, 130), analyze.Interval(500, 510)]
        score = analyze.score(found, truth)
        self.assertEqual(score.recall, 1.0)
        self.assertEqual(score.false_detections, 1)

    def test_score_with_no_truth(self):
        score = analyze.score([analyze.Interval(1, 2)], [])
        self.assertIsNone(score.recall)
        self.assertEqual(score.false_detections, 1)


class ReportTests(unittest.TestCase):
    def test_pair_report_has_nine_rows(self):
        a = export([mk(0), mk(30000)], events=[marker(0, "together"), marker(30000, "apart")])
        b = export([mk(0), mk(30000)])
        report = analyze.pair_report(a, b)
        rows = [line for line in report.splitlines() if line.startswith("| 20 ") or line.startswith("| 30 ") or line.startswith("| 50 ")]
        self.assertEqual(len(rows), 9)
        self.assertIn("recall", report)


if __name__ == "__main__":
    unittest.main()


class NtpAndFixTimeTests(unittest.TestCase):
    def test_corrected_time_uses_fix_time(self):
        s = export([mk(5000, fix=3000)], ntp_offset_ms=100)
        self.assertEqual(analyze.corrected_time(s.samples[0], s.session), 3100)

    def test_reports_warn_when_ntp_offset_is_unknown(self):
        known = export([mk(0), mk(30000)], ntp_offset_ms=-120)
        unknown = export([mk(0), mk(30000)], ntp_offset_ms=None)
        self.assertIn("NTP offset unknown", analyze.single_report(unknown))
        self.assertNotIn("NTP offset unknown", analyze.single_report(known))
        self.assertIn("NTP offset unknown", analyze.pair_report(known, unknown))
        self.assertNotIn("NTP offset unknown", analyze.pair_report(known, known))
