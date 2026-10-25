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
