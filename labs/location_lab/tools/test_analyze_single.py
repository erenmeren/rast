import unittest

import analyze


def mk(t_ms, lat=41.0, lon=29.0, acc=8.0, pct=80, state="discharging", lifecycle="resumed", fix=None):
    return {
        "session_id": "s",
        "seq": 0,
        "device_time_utc_ms": t_ms,
        "fix_time_utc_ms": t_ms if fix is None else fix,
        "lat": lat,
        "lon": lon,
        "accuracy_m": acc,
        "altitude_m": 0.0,
        "speed_mps": 0.0,
        "heading_deg": 0.0,
        "is_mocked": False,
        "lifecycle": lifecycle,
        "battery_pct": pct,
        "battery_state": state,
    }


SESSION = {
    "id": "s",
    "device_model": "Pixel 9a",
    "os_version": "Android 17",
    "requested_interval_s": 30,
    "requested_accuracy": "high",
    "started_at_utc_ms": 0,
    "ended_at_utc_ms": 600000,
    "ntp_offset_ms": -120,
}


class IntervalTests(unittest.TestCase):
    def test_intervals_and_percentiles(self):
        samples = [mk(0), mk(30000), mk(60000), mk(150000)]
        iv = analyze.intervals(samples)
        self.assertEqual(iv, [30.0, 30.0, 90.0])
        self.assertEqual(analyze.percentile(iv, 50), 30.0)
        self.assertEqual(analyze.percentile(iv, 100), 90.0)
        self.assertEqual(analyze.percentile([], 50), None)

    def test_outages_use_three_times_interval(self):
        samples = [mk(0, lifecycle="paused"), mk(90000), mk(181000, lifecycle="resumed")]
        outages = analyze.outages(samples, 30)
        self.assertEqual(len(outages), 1)
        self.assertEqual(outages[0].start_utc_ms, 90000)
        self.assertEqual(outages[0].length_s, 91.0)
        self.assertEqual(outages[0].lifecycle_before, "resumed")

    def test_sample_ages(self):
        self.assertEqual(analyze.sample_ages([mk(5000, fix=3000)]), [2.0])


class BatteryTests(unittest.TestCase):
    def test_drain_ignores_charging_rows(self):
        hour = 3600000
        samples = [mk(0, pct=100), mk(hour, pct=90)]
        samples += [mk(2 * hour, pct=95, state="charging"), mk(3 * hour, pct=100, state="charging")]
        self.assertAlmostEqual(analyze.battery_drain_per_hour(samples), 10.0, places=6)

    def test_drain_with_charging_in_the_middle(self):
        hour = 3600000
        samples = [mk(0, pct=80), mk(hour, pct=70)]
        samples += [mk(2 * hour, pct=95, state="charging")]
        samples += [mk(3 * hour, pct=95), mk(4 * hour, pct=90)]
        # 10 % over 1 h, then 5 % over 1 h: 15 % over 2 discharging hours.
        self.assertAlmostEqual(analyze.battery_drain_per_hour(samples), 7.5, places=6)

    def test_drain_none_for_short_span(self):
        samples = [mk(0, pct=100), mk(300000, pct=99)]
        self.assertIsNone(analyze.battery_drain_per_hour(samples))


class ReportTests(unittest.TestCase):
    def test_single_report_mentions_requested_interval(self):
        export = analyze.Export(SESSION, [mk(0), mk(30000), mk(60000)], [])
        report = analyze.single_report(export)
        self.assertIn("30 s", report)
        self.assertIn("Pixel 9a", report)
        self.assertIn("-120", report)


class LoadTests(unittest.TestCase):
    def test_load_export_parses_types(self):
        import json
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            (p / "session.json").write_text(json.dumps(SESSION))
            (p / "samples.csv").write_text(
                "session_id,seq,device_time_utc_ms,fix_time_utc_ms,lat,lon,accuracy_m,altitude_m,"
                "speed_mps,heading_deg,is_mocked,lifecycle,battery_pct,battery_state\n"
                "s,0,1000,900,41.0,29.0,8.5,40.0,1.2,90.0,false,paused,80,discharging\n"
            )
            (p / "events.csv").write_text("session_id,time_utc_ms,kind,detail\ns,2000,marker,together\n")
            export = analyze.load_export(p)
        self.assertEqual(export.session["requested_interval_s"], 30)
        s = export.samples[0]
        self.assertEqual(s["seq"], 0)
        self.assertEqual(s["device_time_utc_ms"], 1000)
        self.assertEqual(s["accuracy_m"], 8.5)
        self.assertIs(s["is_mocked"], False)
        self.assertEqual(s["lifecycle"], "paused")
        self.assertEqual(export.events[0]["time_utc_ms"], 2000)
        self.assertEqual(export.events[0]["detail"], "together")


if __name__ == "__main__":
    unittest.main()
