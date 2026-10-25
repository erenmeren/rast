import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import analyze

HERE = Path(__file__).resolve().parent


class Db2ExportTests(unittest.TestCase):
    def test_round_trips_through_load_export(self):
        with tempfile.TemporaryDirectory() as d:
            db = Path(d) / "lab.db"
            c = sqlite3.connect(db)
            c.executescript(
                "create table session(id text, device_id text, device_model text, os_version text, app_version text,"
                " started_at_utc_ms int, ended_at_utc_ms int, requested_interval_s int, requested_accuracy text,"
                " ntp_offset_ms int, notes text);"
                "create table sample(session_id text, seq int, device_time_utc_ms int, fix_time_utc_ms int, lat real,"
                " lon real, accuracy_m real, altitude_m real, speed_mps real, heading_deg real, is_mocked int,"
                " lifecycle text, battery_pct int, battery_state text);"
                "create table event(id integer primary key, session_id text, time_utc_ms int, kind text, detail text);"
            )
            c.execute("insert into session values('s','d','Pixel 9a','Android 17','0.1.0',0,NULL,30,'high',-120,'')")
            c.execute("insert into sample values('s',1,30000,29900,41.0,29.0,8.0,0,0,0,0,'paused',80,'discharging')")
            c.execute("insert into sample values('s',0,0,0,41.0,29.0,8.0,0,0,0,1,'resumed',80,'discharging')")
            c.execute("insert into event(session_id,time_utc_ms,kind,detail) values('s',5,'marker','together')")
            c.commit()
            c.close()
            out = Path(d) / "out"
            subprocess.run([sys.executable, "-I", str(HERE / "db2export.py"), str(db), str(out)], check=True)
            export = analyze.load_export(out)
        self.assertEqual(export.session["ntp_offset_ms"], -120)
        self.assertIsNone(export.session["ended_at_utc_ms"])
        self.assertEqual([s["seq"] for s in export.samples], [0, 1])
        self.assertIs(export.samples[0]["is_mocked"], True)
        self.assertIs(export.samples[1]["is_mocked"], False)
        self.assertEqual(export.events[0]["detail"], "together")


if __name__ == "__main__":
    unittest.main()
