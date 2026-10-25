# Backend core (Phase 5a) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SQL migrations for the rast schema, location intake with encounter evaluation, the delay policy, transactional pair operations and retention, proven by a Python test suite against a local PostGIS container.

**Architecture:** Eight ordered migrations under `supabase/migrations/`, `public` for tables and client RPCs, `app` for internal helpers. Tests are stdlib `unittest`; a harness starts `postgis/postgis:17-3.5` in docker, applies `tests/auth_stub.sql` (Supabase look-alike roles and `auth.uid()`) then the migrations, and runs each test as one `begin … rollback` psql script.

**Tech Stack:** PostgreSQL 17, PostGIS 3.5, plpgsql, Python 3 stdlib (`unittest`, `subprocess`, `json`), docker CLI.

**Spec:** `docs/superpowers/specs/2026-10-25-backend-core-design.md`

## Global Constraints

- Every public table has RLS enabled; `anon` gets no grants; `authenticated` gets only the policies the spec lists; clients never read `location_sample`.
- Distance is centre to centre, `round(ST_Distance(a, b)::numeric, 3) <= radius_m` (20.000 passes, 20.001 fails); accuracy is a gate, never subtracted.
- `release_at = encountered_at + greatest(delay_a, delay_b) hours`; a delay reduction never moves `release_at` earlier.
- Allowed `delay_hours`: `0,1,2,4,6,12,18,24` default `2`; allowed `interval_s`: `15,30,45,60,75,90,105,120` default `30`; ages `18..99`, `99` open-ended.
- Provisional `encounter_params` seed: `radius_m 20, max_skew_s 60, max_sample_age_s 86400, max_future_s 60, max_accuracy_m 50, rule_version 1`.
- Public RPCs are `security definer`, `set search_path = public, app, extensions`, act as `app.uid()`, and are idempotent on `client_op_id` where they take one.
- Tests: `python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'`; the harness needs the docker CLI and the image `postgis/postgis:17-3.5`.

## Review Focus

- A sample with latitude 91, longitude 200 or a non-numeric field must be rejected as `malformed`, not raise (Task 5).
- `submit_location_samples('[]')` and a non-array payload return `{"accepted":[],"rejected":[]}` and an error respectively, never a partial insert (Task 5).
- `like_account(self)` and `send_message(self)` must return `unavailable`, never create a pair with `a = b` (Task 7).
- A message body that is empty or longer than 2000 characters is rejected (Task 7).
- A disconnect issued while another session holds the pair lock in an unfinished like must wait and win; the final state is disconnected with no match (Task 7).

---

### Task 1: Test harness, auth stub and extensions migration

**Files:**
- Create: `supabase/migrations/0001_extensions.sql`
- Create: `supabase/tests/auth_stub.sql`
- Create: `supabase/tests/harness.py`
- Create: `supabase/tests/test_harness.py`
- Create: `supabase/README.md`

**Interfaces:**
- Produces: `harness.Db` (module singleton via `harness.db()`): `run(sql: str) -> list[list[str]]` runs one psql script with `-At -F '\t'` inside `begin; … rollback;` unless `commit=True`; raises `harness.SqlError(stderr)` on failure. `harness.as_user(uid: str, sql: str) -> str` wraps SQL in `set local role authenticated; set local "request.jwt.claim.sub" = '<uid>'; <sql>; reset role;`. `harness.uuid(n: int) -> str` deterministic `00000000-0000-0000-0000-00000000000n`.
- Produces: `auth_stub.sql`: schema `auth`, table `auth.users(id uuid pk, phone text)`, function `auth.uid()` returning `nullif(current_setting('request.jwt.claim.sub', true), '')::uuid`, roles `anon`, `authenticated`, `service_role` (nologin), and Supabase-style default privileges granting all on public tables, sequences and functions to those roles.
- Produces: `0001_extensions.sql`: `create schema if not exists extensions; create extension if not exists postgis; create schema if not exists app; revoke all on schema app from public; grant usage on schema app to postgres;`.

- [ ] **Step 1: Write the failing test**

```python
# supabase/tests/test_harness.py
import unittest
import harness

class HarnessTests(unittest.TestCase):
    def test_migrations_apply_and_postgis_is_available(self):
        rows = harness.db().run("select postgis_full_version() like 'POSTGIS=%', (select count(*) from pg_namespace where nspname = 'app');")
        self.assertEqual(rows, [["t", "1"]])

    def test_as_user_sets_auth_uid(self):
        rows = harness.db().run(harness.as_user(harness.uuid(1), "select auth.uid();"))
        self.assertEqual(rows, [[harness.uuid(1)]])

    def test_sql_errors_raise(self):
        with self.assertRaises(harness.SqlError):
            harness.db().run("select 1/0;")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -I -m unittest discover -s supabase/tests -p 'test_harness.py'`
Expected: FAIL with `ModuleNotFoundError: No module named 'harness'`

- [ ] **Step 3: Implement `harness.py`**

`Db.__init__` runs `docker run -d --rm -e POSTGRES_PASSWORD=test postgis/postgis:17-3.5`, polls `docker exec <cid> pg_isready -U postgres` up to 60 s, applies `auth_stub.sql` then every `migrations/*.sql` sorted, each via `docker exec -i <cid> psql -U postgres -d postgres -v ON_ERROR_STOP=1 -X -q` with the file on stdin. `atexit` runs `docker stop <cid>`. `run()` sends `begin;\n<sql>\nrollback;` with `-At -F $'\t'` and splits stdout lines on tabs; empty stdout gives `[]`. Reuse one container per process (`db()` caches the instance). Set `RAST_PG_CONTAINER` to reuse an existing container id instead of starting one.

- [ ] **Step 4: Write `auth_stub.sql`, `0001_extensions.sql` and `README.md`** (README: prerequisites, the test command, `supabase db push` note, the `RAST_PG_CONTAINER` variable).

- [ ] **Step 5: Run test to verify it passes**

Run: `python3 -I -m unittest discover -s supabase/tests -p 'test_harness.py'`
Expected: `Ran 3 tests … OK`

- [ ] **Step 6: Commit**

```bash
git add supabase docs/superpowers/plans/2026-10-25-backend-core.md docs/superpowers/specs/2026-10-25-backend-core-design.md
git commit -m "feat(backend): test harness on a PostGIS container, auth stub, extensions migration"
```

### Task 2: Accounts, profiles, photos, preferences

**Files:**
- Create: `supabase/migrations/0002_accounts.sql`
- Modify: `supabase/tests/harness.py` (add `member()` fixture)
- Create: `supabase/tests/test_accounts.py`

**Interfaces:**
- Consumes: Task 1 harness.
- Produces: enums `account_status`, `gender_identity`, `photo_state`, `interest`; tables `account`, `profile`, `photo`, `preferences`, `intro_progress`, `device`, `entitlement` exactly as the spec table lists, with RLS and own-row policies (`auth.uid() = account_id` / `= id`); `entitlement` select-only for `authenticated`.
- Produces: `harness.member(n: int, *, birth='1998-05-14', gender='woman', custom='', interests="{everyone}", min_age=18, max_age=99, delay=2, interval=30, visible=True, photos=4, status='active') -> str` returning SQL that inserts `auth.users`, `account`, `profile`, `preferences`, `photos` (slots `0..photos-1`, state `ready`, path `p<n>/<slot>.jpg`) and one `device` with id `harness.uuid(100 + n)` for account `harness.uuid(n)`.

- [ ] **Step 1: Write the failing tests**

```python
# supabase/tests/test_accounts.py
class AccountTests(unittest.TestCase):
    def test_member_fixture_inserts_a_complete_member(self):
        rows = db().run(member(1) + "select (select count(*) from profile), (select count(*) from photo where state = 'ready'), (select delay_hours from preferences);")
        self.assertEqual(rows, [["1", "4", "2"]])

    def test_self_described_gender_needs_text(self):
        with self.assertRaises(SqlError):
            db().run(member(1, gender='self', custom=''))
        db().run(member(1, gender='self', custom='genderfluid'))

    def test_preference_constraints(self):
        for bad in [dict(min_age=30, max_age=20), dict(min_age=17), dict(max_age=100), dict(delay=3), dict(interval=20), dict(interests="{}")]:
            with self.subTest(bad=bad), self.assertRaises(SqlError):
                db().run(member(1, **bad))

    def test_everyone_cannot_combine_with_specific_interests(self):
        with self.assertRaises(SqlError):
            db().run(member(1, interests="{everyone,women}"))

    def test_photo_slot_unique_among_live_photos(self):
        sql = member(1) + "insert into photo(id, account_id, slot, storage_path, state) values (gen_random_uuid(), '%s', 0, 'x', 'uploading');" % uuid(1)
        with self.assertRaises(SqlError):
            db().run(sql)

    def test_rls_own_rows_only(self):
        sql = member(1) + member(2) + as_user(uuid(1), "select count(*) from profile; select count(*) from preferences; select count(*) from device;")
        self.assertEqual(db().run(sql), [["1"], ["1"], ["1"]])

    def test_anon_sees_nothing(self):
        with self.assertRaises(SqlError):
            db().run(member(1) + "set local role anon; select count(*) from profile;")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `python3 -I -m unittest discover -s supabase/tests -p 'test_accounts.py'`
Expected: FAIL (`member` not defined, then `relation "profile" does not exist`)

- [ ] **Step 3: Write `0002_accounts.sql` and `member()`**

Interests check: `cardinality(interests) > 0 and (not ('everyone' = any(interests)) or cardinality(interests) = 1)`. `revoke all on all tables in schema public from anon;` at the end of the file (the stub's default privileges granted them).

- [ ] **Step 4: Run tests to verify they pass**

Run: `python3 -I -m unittest discover -s supabase/tests -p 'test_accounts.py'`
Expected: `Ran 7 tests … OK`

- [ ] **Step 5: Commit** — `git commit -m "feat(backend): account, profile, photo, preferences tables with RLS"`

### Task 3: Pair, encounter, message, report tables and params

**Files:**
- Create: `supabase/migrations/0003_pairs.sql`
- Create: `supabase/tests/test_pairs.py`

**Interfaces:**
- Produces: enums `encounter_state`, `report_status`; tables `pair`, `pair_like`, `block`, `encounter`, `message` (`body` check `length(body) between 1 and 2000`), `report`, `pair_event`, `encounter_params` (seeded with the Global Constraints values) as the spec lists; grants for `authenticated`: select on `pair`, `pair_like`, `message`, `pair_event` under policy `auth.uid() in (a, b)` (via join to `pair` for the child tables); `encounter`: `grant select (id, pair_id, state, rule_version, created_at)` only; `block` and `report`: own rows (`blocker = auth.uid()`, `reporter = auth.uid()`); `encounter_params`: select for `authenticated`; no insert/update/delete for `authenticated` on any of these.

- [ ] **Step 1: Write the failing tests**

```python
class PairTableTests(unittest.TestCase):
    def test_pair_is_canonical_and_unique(self):
        with self.assertRaises(SqlError):
            db().run(member(1) + member(2) + "insert into pair(id, a, b) values (gen_random_uuid(), '%s', '%s');" % (uuid(2), uuid(1)))
        with self.assertRaises(SqlError):
            db().run(member(1) + member(2) + ("insert into pair(id, a, b) values (gen_random_uuid(), '%s', '%s');" % (uuid(1), uuid(2))) * 2)

    def test_one_live_encounter_per_pair(self):
        base = member(1) + member(2) + "insert into pair(id, a, b) values ('%s', '%s', '%s');" % (uuid(50), uuid(1), uuid(2))
        enc = "insert into encounter(id, pair_id, encountered_at, rule_version, release_at, state) values (gen_random_uuid(), '%s', now(), 1, now(), '%s');"
        with self.assertRaises(SqlError):
            db().run(base + enc % (uuid(50), 'pending') + enc % (uuid(50), 'released'))
        rows = db().run(base + enc % (uuid(50), 'void') + enc % (uuid(50), 'pending') + "select count(*) from encounter;")
        self.assertEqual(rows, [["2"]])

    def test_encounter_times_are_not_selectable_by_clients(self):
        base = member(1) + member(2) + "insert into pair(id, a, b) values ('%s', '%s', '%s');" % (uuid(50), uuid(1), uuid(2))
        self.assertEqual(db().run(base + as_user(uuid(1), "select count(*) from encounter;")), [["0"]])
        with self.assertRaises(SqlError):
            db().run(base + as_user(uuid(1), "select release_at from encounter;"))
        with self.assertRaises(SqlError):
            db().run(base + as_user(uuid(1), "select encountered_at from encounter;"))

    def test_pair_rows_visible_only_to_members(self):
        base = member(1) + member(2) + member(3) + "insert into pair(id, a, b) values ('%s', '%s', '%s');" % (uuid(50), uuid(1), uuid(2))
        self.assertEqual(db().run(base + as_user(uuid(2), "select count(*) from pair;")), [["1"]])
        self.assertEqual(db().run(base + as_user(uuid(3), "select count(*) from pair;")), [["0"]])

    def test_clients_cannot_write_pair_tables(self):
        for stmt in ["insert into pair(id, a, b) values (gen_random_uuid(), '%s', '%s')" % (uuid(1), uuid(2)), "insert into block(blocker, blocked) values ('%s', '%s')" % (uuid(1), uuid(2))]:
            with self.subTest(stmt=stmt), self.assertRaises(SqlError):
                db().run(member(1) + member(2) + as_user(uuid(1), stmt + ";"))

    def test_params_single_row_seed(self):
        self.assertEqual(db().run("select radius_m, max_skew_s, max_sample_age_s, max_future_s, max_accuracy_m, rule_version from encounter_params;"), [["20", "60", "86400", "60", "50", "1"]])
        with self.assertRaises(SqlError):
            db().run("insert into encounter_params(id, radius_m, max_skew_s, max_sample_age_s, max_future_s, max_accuracy_m, rule_version) values (false, 1, 1, 1, 1, 1, 1);")

    def test_message_body_length(self):
        base = member(1) + member(2) + "insert into pair(id, a, b) values ('%s', '%s', '%s');" % (uuid(50), uuid(1), uuid(2))
        for body in ["''", "repeat('x', 2001)"]:
            with self.subTest(body=body), self.assertRaises(SqlError):
                db().run(base + "insert into message(id, pair_id, sender, client_op_id, seq, body) values (gen_random_uuid(), '%s', '%s', gen_random_uuid(), 1, %s);" % (uuid(50), uuid(1), body))
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: `relation "pair" does not exist`
- [ ] **Step 3: Write `0003_pairs.sql`** (`radius_m` etc. as `numeric`/`int` so the seed prints as `20`, not `20.0`: use `int` for all six)
- [ ] **Step 4: Run tests to verify they pass** — Expected: `Ran 7 tests … OK`
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): pair, encounter, message, report tables, params and policies"`

### Task 4: Internal helpers

**Files:**
- Create: `supabase/migrations/0004_helpers.sql`
- Create: `supabase/tests/test_helpers.py`

**Interfaces:**
- Produces (all in `app`, `language sql` or `plpgsql`, `stable` unless noted): `age_on(birth date, today date) int`; `uid() uuid` (raises `P0001 not_authenticated` when `auth.uid()` is null); `pair_for(x uuid, y uuid) uuid` (volatile, inserts when missing, raises when `x = y`); `setup_complete(acct uuid) bool`; `mutual_preferences(x uuid, y uuid) bool`; `pair_open(pair uuid) bool`; `eligible_pair(x uuid, y uuid) bool`; `effective_delay_hours(x uuid, y uuid) int`.

- [ ] **Step 1: Write the failing tests**

```python
class HelperTests(unittest.TestCase):
    def test_age_on(self):
        rows = db().run("select app.age_on('1998-05-14', '2026-10-25'), app.age_on('1998-10-26', '2026-10-25'), app.age_on('2008-02-29', '2026-02-28'), app.age_on('2008-02-29', '2026-03-01');")
        self.assertEqual(rows, [["28", "27", "17", "18"]])

    def test_uid_requires_auth(self):
        with self.assertRaises(SqlError):
            db().run("select app.uid();")
        self.assertEqual(db().run(as_user(uuid(1), "select app.uid();")), [[uuid(1)]])

    def test_pair_for_is_canonical_and_idempotent(self):
        rows = db().run(member(1) + member(2) + "select app.pair_for('%s','%s') = app.pair_for('%s','%s'), (select count(*) from pair), (select a < b from pair);" % (uuid(1), uuid(2), uuid(2), uuid(1)))
        self.assertEqual(rows, [["t", "1", "t"]])
        with self.assertRaises(SqlError):
            db().run(member(1) + "select app.pair_for('%s','%s');" % (uuid(1), uuid(1)))

    def test_setup_complete_gates(self):
        ok = member(1) + "select app.setup_complete('%s');" % uuid(1)
        self.assertEqual(db().run(ok), [["t"]])
        for bad in [dict(birth='2010-01-01'), dict(visible=False), dict(photos=3), dict(status='deleted'), dict(gender='self', custom='x', photos=3)]:
            with self.subTest(bad=bad):
                self.assertEqual(db().run(member(1, **bad) + "select app.setup_complete('%s');" % uuid(1)), [["f"]])

    def test_mutual_preferences(self):
        def check(a, b):
            return db().run(member(1, **a) + member(2, **b) + "select app.mutual_preferences('%s','%s');" % (uuid(1), uuid(2)))[0][0]
        self.assertEqual(check(dict(gender='woman', interests='{men}'), dict(gender='man', interests='{women}')), 't')
        self.assertEqual(check(dict(gender='woman', interests='{men}'), dict(gender='man', interests='{men}')), 'f')
        self.assertEqual(check(dict(gender='self', custom='x', interests='{everyone}'), dict(gender='man', interests='{everyone}')), 't')
        self.assertEqual(check(dict(gender='self', custom='x', interests='{everyone}'), dict(gender='man', interests='{women,men,nonbinary}')), 'f')
        self.assertEqual(check(dict(birth='1920-01-01', interests='{everyone}', max_age=99), dict(interests='{everyone}', max_age=99)), 't')
        self.assertEqual(check(dict(birth='1920-01-01', interests='{everyone}'), dict(interests='{everyone}', max_age=98)), 'f')
        self.assertEqual(check(dict(interests='{everyone}', min_age=30), dict(interests='{everyone}')), 'f')

    def test_pair_open_and_eligible_pair(self):
        base = member(1) + member(2)
        self.assertEqual(db().run(base + "select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2))), [["t"]])
        self.assertEqual(db().run(base + "insert into block(blocker, blocked) values ('%s','%s'); select app.eligible_pair('%s','%s');" % (uuid(2), uuid(1), uuid(1), uuid(2))), [["f"]])
        self.assertEqual(db().run(base + "update pair set disconnected_at = now() where id = app.pair_for('%s','%s'); select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2), uuid(1), uuid(2))), [["f"]])

    def test_effective_delay(self):
        self.assertEqual(db().run(member(1, delay=0) + member(2, delay=6) + "select app.effective_delay_hours('%s','%s');" % (uuid(1), uuid(2))), [["6"]])
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: `function app.age_on(unknown, unknown) does not exist`
- [ ] **Step 3: Write `0004_helpers.sql`** (`setup_complete` counts `photo` rows with `state = 'ready'` = 4 and uses `age_on(birth_date, current_date) >= 18`; `mutual_preferences` uses `age_on` and treats `max_age = 99` as unbounded)
- [ ] **Step 4: Run tests to verify they pass** — Expected: `Ran 7 tests … OK`
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): eligibility, preference and pair helpers"`

### Task 5: Location intake and encounter evaluation

**Files:**
- Create: `supabase/migrations/0005_location.sql`
- Modify: `supabase/tests/harness.py` (add `sample()` fixture)
- Create: `supabase/tests/test_encounters.py`

**Interfaces:**
- Produces: table `location_sample` (spec columns, unique `(device_id, seq)`, indexes, RLS on, no grants to `anon`/`authenticated`); `public.submit_location_samples(samples jsonb) returns jsonb`; `app.evaluate_encounters(sample_id uuid) returns int` (encounters inserted); `app.release_due_encounters() returns int`.
- Produces: `harness.sample(n: int, seq: int, *, lat=41.0, lon=29.0, bearing=0, distance=0, accuracy=10, observed="now()", device=None, sample_id=None) -> str` returning SQL that calls `submit_location_samples` as user `n` with one sample whose point is `ST_Project(ST_MakePoint(lon, lat)::geography, distance, radians(bearing))`; `device` defaults to `uuid(100 + n)`.

- [ ] **Step 1: Write the failing tests**

```python
class EncounterTests(unittest.TestCase):
    def two(self, **kw):
        return member(1, **kw.get('a', {})) + member(2, **kw.get('b', {}))

    def count(self, sql):
        return db().run(sql + "select count(*) from encounter;")[0][0]

    def test_rule_01_20_metres_passes(self):
        self.assertEqual(self.count(self.two() + sample(1, 1) + sample(2, 1, distance=20.0)), "1")

    def test_rule_02_03_beyond_20_fails(self):
        for d in [20.001, 35, 40]:
            with self.subTest(d=d):
                self.assertEqual(self.count(self.two() + sample(1, 1) + sample(2, 1, distance=d)), "0")

    def test_encounter_fields(self):
        rows = db().run(self.two(a=dict(delay=1), b=dict(delay=4)) + sample(1, 1, observed="'2026-10-25T10:00:00Z'") + sample(2, 1, distance=5, observed="'2026-10-25T10:00:30Z'")
                        + "select state, rule_version, encountered_at, release_at, pair_id = app.pair_for('%s','%s') from encounter;" % (uuid(1), uuid(2)))
        self.assertEqual(rows, [["pending", "1", "2026-10-25 10:00:30+00", "2026-10-25 14:00:30+00", "t"]])

    def test_rule_04_ineligible_pairs(self):
        cases = [dict(a=dict(birth='2010-01-01')), dict(a=dict(visible=False)), dict(b=dict(photos=3)),
                 dict(a=dict(interests='{women}'), b=dict(gender='man')), dict(a=dict(max_age=25), b=dict(birth='1990-01-01'))]
        for c in cases:
            with self.subTest(c=c):
                self.assertEqual(self.count(self.two(**c) + sample(1, 1) + sample(2, 1, distance=5)), "0")
        blocked = self.two() + "insert into block(blocker, blocked) values ('%s','%s');" % (uuid(1), uuid(2))
        self.assertEqual(self.count(blocked + sample(1, 1) + sample(2, 1, distance=5)), "0")
        gone = self.two() + "update pair set disconnected_at = now() where id = app.pair_for('%s','%s');" % (uuid(1), uuid(2))
        self.assertEqual(self.count(gone + sample(1, 1) + sample(2, 1, distance=5)), "0")

    def test_rule_05_stale_skewed_or_inaccurate(self):
        self.assertEqual(self.count(self.two() + sample(1, 1, observed="now() - interval '61 seconds'") + sample(2, 1, distance=5)), "0")
        self.assertEqual(self.count(self.two() + sample(1, 1, observed="now() - interval '59 seconds'") + sample(2, 1, distance=5)), "1")
        self.assertEqual(self.count(self.two() + sample(1, 1, accuracy=51) + sample(2, 1, distance=5)), "0")

    def test_rejections_are_reported(self):
        def result(sql):
            return json.loads(db().run(member(1) + member(2) + sql)[-1][0])
        self.assertEqual(result(sample(1, 1, observed="now() - interval '25 hours'"))["rejected"][0]["reason"], "too_old")
        self.assertEqual(result(sample(1, 1, observed="now() + interval '2 minutes'"))["rejected"][0]["reason"], "future")
        self.assertEqual(result(sample(1, 1, accuracy=51))["rejected"][0]["reason"], "inaccurate")
        self.assertEqual(result(sample(1, 1, device=uuid(102)))["rejected"][0]["reason"], "device")
        self.assertEqual(result(sample(1, 1, lat=91))["rejected"][0]["reason"], "malformed")
        ok = result(sample(1, 1, sample_id=uuid(900)))
        self.assertEqual((ok["accepted"], ok["rejected"]), ([uuid(900)], []))

    def test_duplicate_seq_is_accepted_once(self):
        rows = db().run(member(1) + sample(1, 1, sample_id=uuid(900)) + sample(1, 1, sample_id=uuid(901)) + "select count(*) from location_sample;")
        self.assertEqual(rows[-1], ["1"])
        self.assertEqual(json.loads(rows[1][0])["accepted"], [uuid(901)])

    def test_empty_and_invalid_payloads(self):
        self.assertEqual(json.loads(db().run(member(1) + as_user(uuid(1), "select public.submit_location_samples('[]');"))[0][0]), {"accepted": [], "rejected": []})
        with self.assertRaises(SqlError):
            db().run(member(1) + as_user(uuid(1), "select public.submit_location_samples('{\"a\":1}');"))

    def test_response_names_no_one_else(self):
        out = db().run(self.two() + sample(1, 1) + sample(2, 1, distance=5))[-1][0]
        self.assertNotIn(uuid(1), out)

    def test_one_live_encounter_per_pair(self):
        sql = self.two() + sample(1, 1) + sample(2, 1, distance=5) + sample(1, 2, distance=1) + sample(2, 2, distance=2)
        self.assertEqual(self.count(sql), "1")

    def test_release_due_flips_at_boundary(self):
        base = self.two(a=dict(delay=0), b=dict(delay=0)) + sample(1, 1, observed="now() - interval '1 second'") + sample(2, 1, distance=5, observed="now() - interval '1 second'")
        self.assertEqual(db().run(base + "select app.release_due_encounters(); select state from encounter;"), [["1"], ["released"]])
        later = self.two(a=dict(delay=1), b=dict(delay=0)) + sample(1, 1) + sample(2, 1, distance=5)
        self.assertEqual(db().run(later + "select app.release_due_encounters(); select state from encounter;"), [["0"], ["pending"]])

    def test_clients_cannot_read_samples(self):
        with self.assertRaises(SqlError):
            db().run(member(1) + sample(1, 1) + as_user(uuid(1), "select count(*) from location_sample;"))
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: `sample` not defined, then `function public.submit_location_samples(jsonb) does not exist`
- [ ] **Step 3: Write `0005_location.sql` and `sample()`**

Validation order per element: shape (`jsonb_typeof` checks, `lat` in `[-90, 90]`, `lon` in `[-180, 180]`, `accuracy_m >= 0`) → `malformed`; device ownership → `device`; age → `too_old`; future → `future`; accuracy → `inaccurate`; existing `(device_id, seq)` → accepted without insert. Non-array payload raises `22023`. Evaluation query joins `location_sample` of other accounts within `ST_DWithin` and the skew window, groups by account, applies `round(ST_Distance(..)::numeric, 3) <= radius_m`, then `app.eligible_pair`, inserts with `on conflict do nothing` on the partial index (use `insert … where not exists (live encounter)` because partial unique indexes cannot be named in `on conflict` with a predicate unless the predicate is repeated: write `on conflict (pair_id) where state <> 'void' do nothing`).

- [ ] **Step 4: Run tests to verify they pass** — Expected: `Ran 12 tests … OK`
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): location intake with validation and PostGIS encounter evaluation"`

### Task 6: Delay-change policy

**Files:**
- Create: `supabase/migrations/0006_delay_policy.sql`
- Create: `supabase/tests/test_delay.py`

**Interfaces:**
- Consumes: `encounter`, `preferences`, `app.effective_delay_hours`.
- Produces: trigger `preferences_delay_changed` (`after update of delay_hours on preferences for each row`) calling `app.extend_release_floor()`.

- [ ] **Step 1: Write the failing tests**

```python
class DelayPolicyTests(unittest.TestCase):
    def pending(self):
        return (member(1, delay=2) + member(2, delay=1) + sample(1, 1, observed="'2026-10-25T10:00:00Z'") + sample(2, 1, distance=5, observed="'2026-10-25T10:00:00Z'"))

    def release(self, sql):
        return db().run(sql + "select release_at from encounter;")[-1][0]

    def test_reduction_keeps_the_floor(self):
        self.assertEqual(self.release(self.pending() + "update preferences set delay_hours = 0 where account_id = '%s';" % uuid(1)), "2026-10-25 12:00:00+00")

    def test_increase_extends(self):
        self.assertEqual(self.release(self.pending() + "update preferences set delay_hours = 6 where account_id = '%s';" % uuid(2)), "2026-10-25 16:00:00+00")

    def test_released_rows_untouched(self):
        sql = self.pending() + "update encounter set state = 'released'; update preferences set delay_hours = 24 where account_id = '%s';" % uuid(1)
        self.assertEqual(self.release(sql), "2026-10-25 12:00:00+00")
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: reduction test passes already (floor is stored), increase test FAILS with `12:00:00` instead of `16:00:00`. Confirm the failing one fails for that reason.
- [ ] **Step 3: Write `0006_delay_policy.sql`**
- [ ] **Step 4: Run tests to verify they pass** — Expected: `Ran 3 tests … OK`
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): delay changes extend but never shorten the release floor"`

### Task 7: Pair operations

**Files:**
- Create: `supabase/migrations/0007_pair_ops.sql`
- Modify: `supabase/tests/harness.py` (add `Db.run_concurrent(sql_a, sql_b) -> tuple[list, list]`: two psql processes, A started first with its script, B 0.5 s later; both `commit`, not rollback; returns both outputs; the caller cleans up with `truncate … cascade` of the touched tables since this commits)
- Create: `supabase/tests/test_pair_ops.py`

**Interfaces:**
- Produces (public, `security definer`): `like_account(target uuid, client_op_id uuid) returns jsonb`, `disconnect_pair(target uuid, client_op_id uuid) returns jsonb`, `block_account(target uuid) returns jsonb`, `unblock_account(target uuid) returns jsonb`, `send_message(target uuid, client_op_id uuid, body text) returns jsonb`, `submit_report(target uuid, reason_code text, client_op_id uuid, also_block bool) returns jsonb`, `delete_account() returns jsonb`. Outcomes as the spec lists; `app.lock_pair(x uuid, y uuid) pair` does `pair_for` then `select … for update`.

- [ ] **Step 1: Write the failing tests**

```python
def call(n, fn):
    return as_user(uuid(n), "select public.%s;" % fn)

class PairOpsTests(unittest.TestCase):
    def released(self):
        return (member(1, delay=0) + member(2, delay=0) + sample(1, 1, observed="now() - interval '1 second'")
                + sample(2, 1, distance=5, observed="now() - interval '1 second'") + "select app.release_due_encounters();")

    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def test_like_then_mutual_like_matches(self):
        sql = self.released() + call(1, "like_account('%s','%s')" % (uuid(2), uuid(700)))
        self.assertEqual(self.last(sql)["outcome"], "liked")
        sql += call(2, "like_account('%s','%s')" % (uuid(1), uuid(701)))
        self.assertEqual(self.last(sql)["outcome"], "matched")
        self.assertEqual(db().run(sql + "select matched_at is not null, revision from pair;")[-1], ["t", "2"])

    def test_like_without_released_encounter_is_unavailable(self):
        self.assertEqual(self.last(member(1) + member(2) + call(1, "like_account('%s','%s')" % (uuid(2), uuid(700))))["outcome"], "unavailable")

    def test_like_self_is_unavailable(self):
        self.assertEqual(self.last(member(1) + call(1, "like_account('%s','%s')" % (uuid(1), uuid(700))))["outcome"], "unavailable")

    def test_disconnect_is_idempotent_and_closes_everything(self):
        sql = self.released() + call(1, "like_account('%s','%s')" % (uuid(2), uuid(700))) + call(2, "like_account('%s','%s')" % (uuid(1), uuid(701)))
        sql += call(2, "disconnect_pair('%s','%s')" % (uuid(1), uuid(702)))
        self.assertEqual(self.last(sql)["outcome"], "disconnected")
        sql += call(2, "disconnect_pair('%s','%s')" % (uuid(1), uuid(702)))
        self.assertEqual(self.last(sql)["outcome"], "disconnected")
        rows = db().run(sql + "select revision, disconnected_at is not null from pair; select state from encounter; select count(*) from pair_event where kind = 'disconnected';")
        self.assertEqual(rows[-3:], [["3", "t"], ["void"], ["1"]])
        for fn in ["like_account('%s','%s')" % (uuid(2), uuid(703)), "send_message('%s','%s','hi')" % (uuid(2), uuid(704))]:
            with self.subTest(fn=fn):
                self.assertEqual(self.last(sql + call(1, fn))["outcome"], "unavailable")

    def test_disconnect_without_match_works(self):
        self.assertEqual(self.last(member(1) + member(2) + call(1, "disconnect_pair('%s','%s')" % (uuid(2), uuid(702))))["outcome"], "disconnected")

    def test_block_on_match_disconnects_unblock_keeps_tombstone(self):
        sql = self.released() + call(1, "like_account('%s','%s')" % (uuid(2), uuid(700))) + call(2, "like_account('%s','%s')" % (uuid(1), uuid(701)))
        sql += call(1, "block_account('%s')" % uuid(2)) + call(1, "unblock_account('%s')" % uuid(2))
        rows = db().run(sql + "select count(*) from block; select disconnected_at is not null from pair;")
        self.assertEqual(rows[-2:], [["0"], ["t"]])

    def test_block_unmatched_then_unblock_restores_eligibility(self):
        sql = member(1) + member(2) + call(1, "block_account('%s')" % uuid(2))
        self.assertEqual(db().run(sql + "select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2)))[-1], ["f"])
        sql += call(1, "unblock_account('%s')" % uuid(2))
        self.assertEqual(db().run(sql + "select app.eligible_pair('%s','%s');" % (uuid(1), uuid(2)))[-1], ["t"])

    def test_report_with_block_on_match(self):
        sql = self.released() + call(1, "like_account('%s','%s')" % (uuid(2), uuid(700))) + call(2, "like_account('%s','%s')" % (uuid(1), uuid(701)))
        sql += call(1, "submit_report('%s','harassment','%s', true)" % (uuid(2), uuid(705)))
        self.assertEqual(self.last(sql)["outcome"], "received")
        rows = db().run(sql + "select count(*) from report; select count(*) from block; select disconnected_at is not null from pair;")
        self.assertEqual(rows[-3:], [["1"], ["1"], ["t"]])
        sql += call(1, "submit_report('%s','harassment','%s', true)" % (uuid(2), uuid(705)))
        self.assertEqual(db().run(sql + "select count(*) from report;")[-1], ["1"])

    def test_report_without_block_keeps_connection(self):
        sql = self.released() + call(1, "like_account('%s','%s')" % (uuid(2), uuid(700))) + call(2, "like_account('%s','%s')" % (uuid(1), uuid(701)))
        sql += call(1, "submit_report('%s','spam','%s', false)" % (uuid(2), uuid(705)))
        self.assertEqual(db().run(sql + "select disconnected_at is null from pair;")[-1], ["t"])

    def test_messages_dense_seq_and_idempotent(self):
        sql = self.released() + call(1, "like_account('%s','%s')" % (uuid(2), uuid(700))) + call(2, "like_account('%s','%s')" % (uuid(1), uuid(701)))
        sql += call(1, "send_message('%s','%s','hello')" % (uuid(2), uuid(710))) + call(2, "send_message('%s','%s','hi')" % (uuid(1), uuid(711))) + call(1, "send_message('%s','%s','hello')" % (uuid(2), uuid(710)))
        rows = db().run(sql + "select count(*), max(seq) from message;")
        self.assertEqual(rows[-1], ["2", "2"])
        self.assertEqual(self.last(sql)["seq"], 1)
        self.assertEqual(self.last(self.released() + call(1, "send_message('%s','%s','x')" % (uuid(2), uuid(712))))["outcome"], "unavailable")
        with self.assertRaises(SqlError):
            db().run(sql + call(1, "send_message('%s','%s','')" % (uuid(2), uuid(713))))

    def test_delete_account(self):
        sql = self.released() + call(1, "delete_account()")
        rows = db().run(sql + "select status from account where id = '%s'; select visible from profile where account_id = '%s'; select count(*) from pair;" % (uuid(1), uuid(1)))
        self.assertEqual(rows[-3:], [["deleted"], ["f"], ["1"]])

    def test_disconnect_waits_for_in_flight_like(self):
        setup = self.released()
        db().run(setup, commit=True)
        a = as_user(uuid(1), "select public.like_account('%s','%s'); select pg_sleep(2);" % (uuid(2), uuid(700)))
        b = as_user(uuid(2), "select public.disconnect_pair('%s','%s');" % (uuid(1), uuid(702)))
        try:
            _, out_b = db().run_concurrent(a, b)
            self.assertEqual(json.loads(out_b[-1][0])["outcome"], "disconnected")
            self.assertEqual(db().run("select disconnected_at is not null, matched_at is null from pair;"), [["t", "t"]])
        finally:
            db().run("truncate auth.users cascade; truncate account cascade; truncate pair cascade;", commit=True)
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: `function public.like_account(uuid, uuid) does not exist`
- [ ] **Step 3: Write `0007_pair_ops.sql` and `run_concurrent`**

`like_account` returns `unavailable` when `target = app.uid()`, when no `released` encounter exists for the pair, when `not app.eligible_pair`, or when the pair is closed; otherwise inserts the like (`on conflict do nothing`), and when the reverse like exists and `matched_at is null` sets it; revision bumps on every state change; `pair_event.kind` in `liked`, `matched`, `disconnected`, `blocked`, `unblocked`, `message`. `send_message` returns the existing row for a repeated `client_op_id`.

- [ ] **Step 4: Run tests to verify they pass** — Expected: `Ran 13 tests … OK`
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): transactional like, match, disconnect, block, report and message RPCs"`

### Task 8: Retention, cron scheduling, docs and decision log

**Files:**
- Create: `supabase/migrations/0008_retention.sql`
- Create: `supabase/tests/test_retention.py`
- Modify: `supabase/README.md`, `docs/superpowers/plans/decision-log.md`

**Interfaces:**
- Produces: `app.purge_location_samples() returns int`, `app.purge_void_encounters() returns int`; a `do` block that schedules them with `cron.schedule('purge-location-samples', '17 * * * *', …)` and `('purge-void-encounters', '23 3 * * *', …)` only when `pg_cron` is installed.

- [ ] **Step 1: Write the failing tests**

```python
class RetentionTests(unittest.TestCase):
    def test_samples_older_than_24h_are_purged(self):
        sql = member(1) + sample(1, 1, sample_id=uuid(900)) + sample(1, 2, sample_id=uuid(901)) + "update location_sample set received_at = now() - interval '25 hours' where id = '%s';" % uuid(900)
        rows = db().run(sql + "select app.purge_location_samples(); select id from location_sample;")
        self.assertEqual(rows[-2:], [["1"], [uuid(901)]])

    def test_void_encounters_older_than_30_days_are_purged(self):
        sql = member(1) + member(2) + sample(1, 1) + sample(2, 1, distance=5) + "update encounter set state = 'void', created_at = now() - interval '31 days';"
        self.assertEqual(db().run(sql + "select app.purge_void_encounters(); select count(*) from encounter;")[-2:], [["1"], ["0"]])
        keep = member(1) + member(2) + sample(1, 1) + sample(2, 1, distance=5) + "update encounter set state = 'void';"
        self.assertEqual(db().run(keep + "select app.purge_void_encounters();")[-1], ["0"])

    def test_cron_schedule_is_skipped_without_pg_cron(self):
        self.assertEqual(db().run("select count(*) from pg_extension where extname = 'pg_cron';"), [["0"]])
```

- [ ] **Step 2: Run tests to verify they fail** — Expected: `function app.purge_location_samples() does not exist`
- [ ] **Step 3: Write `0008_retention.sql`; finish `README.md`; append to the decision log** a "2026-10-25 — Backend core (Phase 5a)" entry: layout, provisional thresholds marked "replace after Phase 0", millimetre rounding rule, one-live-encounter dedup, `max_sample_age_s = 24 h` (offline uploads inside retention still count), no partitioning yet, `delete_account` scope.
- [ ] **Step 4: Run the whole suite** — Run: `python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'` Expected: all tests OK (3 + 7 + 7 + 7 + 12 + 3 + 13 + 3 = 55)
- [ ] **Step 5: Commit** — `git commit -m "feat(backend): retention jobs, cron scheduling, docs"`
