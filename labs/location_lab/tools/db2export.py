import csv, json, sqlite3, sys
from pathlib import Path
db, out = sys.argv[1], Path(sys.argv[2])
c = sqlite3.connect(db); c.row_factory = sqlite3.Row
sess = dict(c.execute("select * from session order by started_at_utc_ms desc limit 1").fetchone())
out.mkdir(parents=True, exist_ok=True)
(out / "session.json").write_text(json.dumps(sess, indent=2))
cols = ['session_id','seq','device_time_utc_ms','fix_time_utc_ms','lat','lon','accuracy_m','altitude_m','speed_mps','heading_deg','is_mocked','lifecycle','battery_pct','battery_state']
with open(out / "samples.csv", "w", newline="") as f:
    w = csv.writer(f); w.writerow(cols)
    for r in c.execute("select * from sample where session_id=? order by seq", (sess["id"],)):
        row = [r[k] for k in cols]; row[10] = "true" if r["is_mocked"] else "false"; w.writerow(row)
with open(out / "events.csv", "w", newline="") as f:
    w = csv.writer(f); w.writerow(['session_id','time_utc_ms','kind','detail'])
    for r in c.execute("select * from event where session_id=? order by time_utc_ms", (sess["id"],)):
        w.writerow([r["session_id"], r["time_utc_ms"], r["kind"], r["detail"]])
print(sess["id"], out)
