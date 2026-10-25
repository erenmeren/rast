"""Runs SQL against a throwaway PostGIS container. Stdlib only.

One container per test process. Migrations and the auth stub are applied
once; every `run()` is its own `begin … rollback` script unless
`commit=True`. Set RAST_PG_CONTAINER to reuse a running container.
"""
import atexit
import os
import subprocess
import time
from pathlib import Path

IMAGE = "postgis/postgis:17-3.5"
HERE = Path(__file__).resolve().parent
MIGRATIONS = HERE.parent / "migrations"


class SqlError(Exception):
    pass


def uuid(n: int) -> str:
    return "00000000-0000-0000-0000-%012d" % n


def as_user(uid: str, sql: str) -> str:
    return (
        "set local role authenticated; set local \"request.jwt.claim.sub\" = '%s';\n%s\nreset role;\n"
        % (uid, sql)
    )


def member(n: int, *, birth="1998-05-14", gender="woman", custom="", interests="{everyone}",
           min_age=18, max_age=99, delay=2, interval=30, visible=True, photos=4, status="active") -> str:
    """SQL inserting a complete member: auth user, account, profile, preferences, photos, one device."""
    acct, dev = uuid(n), uuid(100 + n)
    sql = [
        "insert into auth.users(id, phone) values ('%s', '+90555%07d');" % (acct, n),
        "insert into account(id, status) values ('%s', '%s');" % (acct, status),
        "insert into profile(account_id, birth_date, gender, custom_gender, visible) values ('%s', '%s', '%s', '%s', %s);"
        % (acct, birth, gender, custom, "true" if visible else "false"),
        "insert into preferences(account_id, interests, min_age, max_age, delay_hours, interval_s) values ('%s', '%s', %d, %d, %d, %d);"
        % (acct, interests, min_age, max_age, delay, interval),
        "insert into device(id, account_id, platform) values ('%s', '%s', 'test');" % (dev, acct),
    ]
    for slot in range(photos):
        sql.append("insert into photo(account_id, slot, storage_path, state) values ('%s', %d, 'p%d/%d.jpg', 'ready');" % (acct, slot, n, slot))
    return "\n".join(sql) + "\n"


def sample(n: int, seq: int, *, lat=41.0, lon=29.0, bearing=0, distance=0, accuracy=10,
           observed="now()", device=None, sample_id=None) -> str:
    """SQL submitting one sample as user n, `distance` metres from (lat, lon) along `bearing`."""
    device = device or uuid(100 + n)
    sid = "'%s'" % sample_id if sample_id else "gen_random_uuid()"
    if distance:
        point = "ST_Project(ST_SetSRID(ST_MakePoint(%r, %r), 4326)::geography, %r, radians(%r))::geometry" % (lon, lat, distance, bearing)
        lat_sql, lon_sql = "ST_Y(%s)" % point, "ST_X(%s)" % point
    else:
        # raw values, so malformed coordinates reach the RPC untouched
        lat_sql, lon_sql = repr(lat), repr(lon)
    call = (
        "select public.submit_location_samples(jsonb_build_array(jsonb_build_object("
        "'id', %s, 'device_id', '%s', 'seq', %d, 'lat', %s, 'lon', %s, "
        "'accuracy_m', %r, 'observed_at', (%s)::timestamptz)));"
        % (sid, device, seq, lat_sql, lon_sql, accuracy, observed)
    )
    return as_user(uuid(n), call)


class Db:
    def __init__(self):
        self.cid = os.environ.get("RAST_PG_CONTAINER")
        self.owned = self.cid is None
        if self.owned:
            self.cid = subprocess.run(
                ["docker", "run", "-d", "--rm", "-e", "POSTGRES_PASSWORD=test", IMAGE],
                check=True, capture_output=True, text=True,
            ).stdout.strip()
            atexit.register(self.stop)
            self._wait_ready()
            self._apply(HERE / "auth_stub.sql")
            for migration in sorted(MIGRATIONS.glob("*.sql")):
                self._apply(migration)

    def stop(self):
        if self.owned:
            subprocess.run(["docker", "stop", self.cid], capture_output=True)

    def _wait_ready(self):
        for _ in range(120):
            ok = subprocess.run(["docker", "exec", self.cid, "pg_isready", "-U", "postgres"], capture_output=True)
            if ok.returncode == 0:
                # pg_isready can answer before the init scripts restart the server.
                time.sleep(1.5)
                ok = subprocess.run(["docker", "exec", self.cid, "pg_isready", "-U", "postgres"], capture_output=True)
                if ok.returncode == 0:
                    return
            time.sleep(0.5)
        raise RuntimeError("postgres did not become ready")

    def _psql(self, script: str, *flags: str) -> str:
        cmd = ["docker", "exec", "-i", self.cid, "psql", "-U", "postgres", "-d", "postgres",
               "-v", "ON_ERROR_STOP=1", "-X", "-q", *flags]
        done = subprocess.run(cmd, input=script, capture_output=True, text=True)
        if done.returncode != 0:
            raise SqlError(done.stderr.strip())
        return done.stdout

    def _apply(self, path: Path):
        try:
            self._psql(path.read_text(encoding="utf-8"))
        except SqlError as e:
            raise SqlError("%s: %s" % (path.name, e)) from None

    def run(self, sql: str, commit: bool = False) -> list:
        script = "begin;\n%s\n%s;\n" % (sql, "commit" if commit else "rollback")
        out = self._psql(script, "-At", "-F", "\t")
        return [line.split("\t") for line in out.splitlines()]


_db = None


def db() -> Db:
    global _db
    if _db is None:
        _db = Db()
    return _db
