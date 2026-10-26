# Discovery, passes and Likes You (Phase 5b) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Server-side Discover deck (stable random order, cursor pages, pass, rewind), Likes You (eligible set, free previews vs premium cards), photo-access rule and the release schedule, as SQL migrations proven by the Python harness.

**Architecture:** Three new migrations on top of `0010`: the cron release job, the discovery slice (tables + RPCs), the Likes You slice (entitlement helper, preview tokens, photo access, purge). Same conventions as 5a: `app` helpers are internal, `public` RPCs are `security definer` and return `jsonb` with an `outcome` key, tests are `begin … rollback` scripts.

**Tech Stack:** PostgreSQL 17 + PostGIS (docker `postgis/postgis:17-3.5`), pg_cron on Supabase, Python 3 stdlib unittest.

**Spec:** `docs/superpowers/specs/2026-10-26-discovery-design.md`

## Global Constraints

- Every new `app` function: `set search_path = public, app, extensions` and an explicit `revoke execute on function … from public, anon, authenticated` (0009 lesson).
- Every new public RPC: `security definer`, `set search_path = public, app, extensions`, `revoke all … from public, anon`, `grant execute … to authenticated`.
- Cards never carry `encountered_at`, `release_at`, `created_at`, distances or like status.
- Deck gate = `app.candidate(me, pair_id)`: released encounter exists, `matched_at is null`, `app.pair_open`, `app.eligible_pair(me, other)`.
- Run tests with `python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'` (docker needed).

## Review Focus

- `page_size` of 0, negative or 500: clamp to 1..50, never error (Task 2 test `test_page_size_is_clamped`).
- `after` that is not a bigint ("abc"): return `{"outcome":"bad_cursor"}` rather than a raw cast error (Task 2 test `test_bad_cursor`).
- A deleted account (`status = 'deleted'`) still has a released pair: `app.eligible_pair` already fails `setup_complete`, so no card; covered by `test_card_disappears_when_other_side_becomes_ineligible` (hidden profile case).
- `likes_you()` by a member whose own setup is incomplete: eligible set is empty, count 0 (Task 3 test `test_incomplete_setup_sees_no_likes`).
- Two sessions started back to back: only the newest survives (Task 2 test `test_new_session_replaces_old`).

---

### Task 1: Release schedule

**Files:**
- Create: `supabase/migrations/0011_release_schedule.sql`
- Modify: `supabase/README.md` (layout table)

**Interfaces:** none new. Uses `app.release_due_encounters()` from 0005.

- [ ] **Step 1: Write `0011_release_schedule.sql`**: a `do $$ … $$` block like 0008 that, when `pg_cron` is installed, runs `cron.schedule('release-due-encounters', '* * * * *', 'select app.release_due_encounters()')`.
- [ ] **Step 2: Run the suite**: `python3 -I -m unittest discover -s supabase/tests -p 'test_*.py'` → `OK` (the local container has no pg_cron, so the block is a no-op; `test_cron_schedule_is_skipped_without_pg_cron` still passes).
- [ ] **Step 3: Add the README row** `| 0011_release_schedule.sql | pg_cron: release_due_encounters every minute |`.
- [ ] **Step 4: Commit** `feat(backend): schedule release_due_encounters every minute`.

### Task 2: Discovery sessions, cards, pass, rewind

**Files:**
- Create: `supabase/migrations/0012_discovery.sql`
- Test: `supabase/tests/test_discovery.py`

**Interfaces:**
- Produces `app.candidate(me uuid, pid uuid) returns boolean`, `app.order_key(seed bigint, pid uuid) returns bigint`, `app.card(acct uuid) returns jsonb`, tables `discovery_session`, `pair_pass`, RPCs `public.start_discovery_session()`, `public.discovery_cards(session_id uuid, after text default null, page_size int default 20)`, `public.pass_account(target uuid, client_op_id uuid)`, `public.rewind_pass()`.
- Task 3 reuses `app.candidate`, `app.card` and the `pair_pass` table.

- [ ] **Step 1: Write the failing tests** in `supabase/tests/test_discovery.py`:

```python
import json
import unittest

from harness import SqlError, as_user, db, member, sample, uuid


def call(n, fn):
    return as_user(uuid(n), "select public.%s;" % fn)


def like(n, target, op):
    return call(n, "like_account('%s','%s')" % (uuid(target), uuid(op)))


def passes(n, target, op):
    return call(n, "pass_account('%s','%s')" % (uuid(target), uuid(op)))


SEED = "update discovery_session set seed = %d;"
SESSION = "(select id from discovery_session limit 1)"


def released_group(*ns, delay=0):
    """Members ns, all within 5 m one second ago, encounters released."""
    sql = "".join(member(n, delay=delay) for n in ns)
    sql += "".join(sample(n, 1, distance=i, observed="now() - interval '1 second'") for i, n in enumerate(ns))
    return sql + "select app.release_due_encounters();"


def cards(n, after="null", page_size=20):
    return call(n, "discovery_cards(%s, %s, %d)" % (SESSION, after, page_size))


class DiscoveryTests(unittest.TestCase):
    def base(self):
        return released_group(1, 2, 3, 4) + call(1, "start_discovery_session()")

    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def ids(self, result):
        return [c["account_id"] for c in result["cards"]]

    def test_order_depends_on_seed_not_time_and_is_stable(self):
        orders = set()
        for seed in range(1, 6):
            sql = self.base() + SEED % seed
            first = self.ids(self.last(sql + cards(1)))
            self.assertEqual(sorted(first), [uuid(2), uuid(3), uuid(4)])
            self.assertEqual(first, self.ids(self.last(sql + cards(1) + cards(1))))
            orders.add(tuple(first))
        self.assertGreater(len(orders), 1)

    def test_card_shape(self):
        sql = self.base() + "update profile set show_gender = true where account_id = '%s';" % uuid(2)
        card = [c for c in self.last(sql + cards(1))["cards"] if c["account_id"] == uuid(2)][0]
        self.assertEqual(card, {"account_id": uuid(2), "age": 28, "gender": "woman", "custom_gender": "",
                                "photos": ["p2/0.jpg", "p2/1.jpg", "p2/2.jpg", "p2/3.jpg"]})
        hidden = [c for c in self.last(sql + cards(1))["cards"] if c["account_id"] == uuid(3)][0]
        self.assertIsNone(hidden["gender"])

    def test_pages_have_no_duplicates_and_no_gaps(self):
        sql = self.base() + SEED % 7
        page1 = self.last(sql + cards(1, page_size=2))
        self.assertEqual(len(page1["cards"]), 2)
        self.assertIsNotNone(page1["next"])
        page2 = self.last(sql + cards(1, after="'%s'" % page1["next"], page_size=2))
        self.assertEqual(len(page2["cards"]), 1)
        self.assertIsNone(page2["next"])
        self.assertEqual(sorted(self.ids(page1) + self.ids(page2)), [uuid(2), uuid(3), uuid(4)])

    def test_liked_and_passed_are_absent(self):
        sql = self.base() + like(1, 2, 700) + passes(1, 3, 701)
        self.assertEqual(self.ids(self.last(sql + cards(1))), [uuid(4)])

    def test_card_disappears_when_other_side_becomes_ineligible(self):
        for change in [call(1, "block_account('%s')" % uuid(2)),
                       call(2, "block_account('%s')" % uuid(1)),
                       "update profile set visible = false where account_id = '%s';" % uuid(2),
                       "update photo set state = 'removed' where account_id = '%s' and slot = 0;" % uuid(2),
                       "update account set status = 'deleted' where id = '%s';" % uuid(2)]:
            with self.subTest(change=change):
                self.assertNotIn(uuid(2), self.ids(self.last(self.base() + change + cards(1))))

    def test_foreign_or_expired_session(self):
        self.assertEqual(self.last(self.base() + cards(2))["outcome"], "session_expired")
        expired = self.base() + "update discovery_session set expires_at = now() - interval '1 second';"
        self.assertEqual(self.last(expired + cards(1))["outcome"], "session_expired")

    def test_new_session_replaces_old(self):
        rows = db().run(self.base() + call(1, "start_discovery_session()") + "select count(*) from discovery_session;")
        self.assertEqual(rows[-1], ["1"])

    def test_page_size_is_clamped(self):
        for size in (0, -5, 500):
            with self.subTest(size=size):
                self.assertEqual(self.last(self.base() + cards(1, page_size=size))["outcome"], "ok")

    def test_bad_cursor(self):
        self.assertEqual(self.last(self.base() + cards(1, after="'abc'"))["outcome"], "bad_cursor")

    def test_late_candidate_joins_only_after_its_slot(self):
        sql = self.base() + SEED % 3
        page1 = self.last(sql + cards(1, page_size=2))
        late = sql + member(5, delay=0) + sample(5, 1, distance=4, observed="now() - interval '1 second'") + "select app.release_due_encounters();"
        page2 = self.last(late + cards(1, after="'%s'" % page1["next"], page_size=20))
        key = db().run(late + "select app.order_key(3, app.pair_for('%s','%s'));" % (uuid(1), uuid(5)))[-1][0]
        self.assertEqual(uuid(5) in self.ids(page2), int(key) > int(page1["next"]))
        fresh = self.last(late + call(1, "start_discovery_session()") + cards(1))
        self.assertIn(uuid(5), self.ids(fresh))

    def test_pass_hides_and_rewind_restores(self):
        sql = self.base() + passes(1, 2, 701)
        self.assertEqual(self.last(sql)["outcome"], "passed")
        self.assertEqual(self.last(sql + passes(1, 2, 702))["outcome"], "passed")
        self.assertNotIn(uuid(2), self.ids(self.last(sql + cards(1))))
        self.assertEqual(self.last(sql + call(1, "rewind_pass()")), {"outcome": "restored", "account_id": uuid(2)})
        self.assertIn(uuid(2), self.ids(self.last(sql + call(1, "rewind_pass()") + cards(1))))
        self.assertEqual(db().run(sql + "select count(*) from pair_event;")[-1], ["0"])

    def test_rewind_keeps_pass_when_pair_is_closed(self):
        sql = self.base() + passes(1, 2, 701) + call(1, "block_account('%s')" % uuid(2))
        self.assertEqual(self.last(sql + call(1, "rewind_pass()"))["outcome"], "unavailable")
        self.assertEqual(db().run(sql + "select count(*) from pair_pass;")[-1], ["1"])
        self.assertEqual(self.last(self.base() + call(1, "rewind_pass()"))["outcome"], "unavailable")

    def test_pass_on_pending_pair_is_unavailable(self):
        self.assertEqual(self.last(released_group(1, 2, delay=2) + passes(1, 2, 701))["outcome"], "unavailable")

    def test_privileges(self):
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run("set local role anon; select public.start_discovery_session();")
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(1), "select app.candidate('%s', gen_random_uuid());" % uuid(1)))
        rows = db().run(self.base() + as_user(uuid(1), "select count(*) from discovery_session;")
                        + as_user(uuid(2), "select count(*) from discovery_session;"))
        self.assertEqual(rows[-2:], [["1"], ["0"]])
```

- [ ] **Step 2: Run** `python3 -I -m unittest supabase/tests/test_discovery.py` from `supabase/tests` (`cd supabase/tests && python3 -I -m unittest test_discovery`) → every test errors with `function public.start_discovery_session() does not exist` or similar.
- [ ] **Step 3: Write `0012_discovery.sql`** with, in this order:
  - `create table discovery_session (id uuid pk default gen_random_uuid(), account_id uuid not null references account(id) on delete cascade, seed bigint not null, created_at timestamptz default now(), expires_at timestamptz not null default now() + interval '24 hours')`; index on `account_id`; RLS; policy `session_own` select for `authenticated` where `account_id = auth.uid()`; `revoke all … from anon, authenticated; grant select … to authenticated`.
  - `create table pair_pass (pair_id uuid references pair(id), from_account uuid references account(id), created_at timestamptz default now(), primary key (pair_id, from_account))`; RLS; policy `pass_own` select where `from_account = auth.uid()`; same grants.
  - `app.candidate(me uuid, pid uuid) returns boolean language sql stable`: as in Global Constraints (the other account is `case when p.a = me then p.b else p.a end`; false when `me` is not a member).
  - `app.order_key(seed bigint, pid uuid) returns bigint language sql immutable`: `hashtextextended(seed::text || pid::text, 0)`.
  - `app.card(acct uuid) returns jsonb language sql stable`: `jsonb_build_object('account_id', acct, 'age', app.age_on(birth_date, current_date), 'gender', case when show_gender then gender::text end, 'custom_gender', case when show_gender and gender = 'self' then custom_gender else '' end, 'photos', (select coalesce(jsonb_agg(storage_path order by slot), '[]') from photo where account_id = acct and state = 'ready'))`.
  - `app.deck(me uuid)` returns `table (pid uuid, other uuid)`: pairs with `me in (a, b)`, `app.candidate(me, id)`, no `pair_like` and no `pair_pass` by `me`.
  - `public.start_discovery_session() returns jsonb`: `me := app.uid()`, delete the caller's sessions, insert with `seed = (random() * 4611686018427387903)::bigint`, return `{"outcome":"ok","session_id":id}`.
  - `public.discovery_cards(session_id uuid, after text default null, page_size int default 20) returns jsonb`: clamp `page_size` to `least(greatest(page_size, 1), 50)`; load the session where `id = session_id and account_id = me and expires_at > now()` else `session_expired`; parse `after` to bigint inside a `begin … exception when others then return {"outcome":"bad_cursor"} end` block; select `page_size + 1` rows from `app.deck(me)` with `app.order_key(seed, pid) > coalesce(cursor, -9223372036854775808)` ordered by `(key, pid)`; return `{"outcome":"ok","cards":[app.card(other) …],"next": key of the last returned card when more than page_size rows exist else null}` (`next` as text).
  - `public.pass_account(target uuid, client_op_id uuid) returns jsonb`: `unavailable` when `target = me`, account missing, or `not app.candidate(me, app.lock_pair(me, target).id)`; else insert into `pair_pass` on conflict do nothing; `passed`.
  - `public.rewind_pass() returns jsonb`: most recent `pair_pass` of `me` by `created_at desc, pair_id`; none → `unavailable`; lock the pair (`select … for update`); if `not app.candidate(me, pid)` → `unavailable`; delete the pass; `{"outcome":"restored","account_id":other}`.
  - Revokes/grants per Global Constraints: `revoke execute on all functions in schema app from public, anon, authenticated; grant execute on function app.pair_visible(uuid, uuid) to authenticated;` and the public RPC revoke/grant.
- [ ] **Step 4: Run** the discovery tests → all pass; then the full suite → `OK`.
- [ ] **Step 5: Commit** `feat(backend): discovery sessions, cursor pages, pass and rewind`.

### Task 3: Likes You, photo access, purge

**Files:**
- Create: `supabase/migrations/0013_likes_you.sql`
- Test: `supabase/tests/test_likes_you.py`

**Interfaces:**
- Consumes `app.candidate`, `app.card`, `pair_pass` from Task 2.
- Produces `app.is_premium(acct uuid) returns boolean`, `app.incoming_likes(me uuid) returns table (pid uuid, other uuid)`, `app.can_view_photos(viewer uuid, owner uuid) returns boolean`, `app.purge_discovery() returns int`, table `like_preview`, RPC `public.likes_you()`.

- [ ] **Step 1: Write the failing tests** in `supabase/tests/test_likes_you.py`:

```python
import json
import unittest

from harness import SqlError, as_user, db, member, sample, uuid
from test_discovery import call, like, passes, released_group


def premium(n, valid="null"):
    return "insert into entitlement(account_id, product, status, valid_until) values ('%s', 'premium', 'active', %s);" % (uuid(n), valid)


class LikesYouTests(unittest.TestCase):
    def base(self):
        return released_group(1, 2, 3, 4) + like(2, 1, 700) + like(3, 1, 701)

    def last(self, sql):
        return json.loads(db().run(sql)[-1][0])

    def test_free_member_gets_count_and_previews_only(self):
        r = self.last(self.base() + call(1, "likes_you()"))
        self.assertEqual((r["outcome"], r["premium"], r["count"]), ("ok", False, 2))
        self.assertEqual(sorted(p["age"] for p in r["previews"]), [28, 28])
        self.assertNotIn("cards", r)
        self.assertEqual(set(r["previews"][0]), {"token", "age"})

    def test_premium_member_gets_cards(self):
        r = self.last(self.base() + premium(1) + call(1, "likes_you()"))
        self.assertEqual((r["premium"], r["count"]), (True, 2))
        self.assertEqual(sorted(c["account_id"] for c in r["cards"]), [uuid(2), uuid(3)])
        self.assertNotIn("previews", r)

    def test_expired_entitlement_is_free(self):
        r = self.last(self.base() + premium(1, "now() - interval '1 day'") + call(1, "likes_you()"))
        self.assertFalse(r["premium"])

    def test_passed_liker_and_pending_liker_are_excluded(self):
        sql = self.base() + passes(1, 2, 702)
        self.assertEqual(self.last(sql + call(1, "likes_you()"))["count"], 1)
        pending = (released_group(1, 2, delay=2)
                   + "insert into pair_like(pair_id, from_account) values (app.pair_for('%s','%s'), '%s');" % (uuid(1), uuid(2), uuid(2)))
        self.assertEqual(self.last(pending + call(1, "likes_you()"))["count"], 0)

    def test_incomplete_setup_sees_no_likes(self):
        sql = self.base() + "update profile set visible = false where account_id = '%s';" % uuid(1)
        self.assertEqual(self.last(sql + call(1, "likes_you()"))["count"], 0)

    def test_tokens_are_reused_and_closed_to_clients(self):
        sql = self.base() + call(1, "likes_you()")
        first = {p["token"] for p in self.last(sql)["previews"]}
        second = {p["token"] for p in self.last(sql + call(1, "likes_you()"))["previews"]}
        self.assertEqual(first, second)
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(sql + as_user(uuid(1), "select * from like_preview;"))

    def test_can_view_photos(self):
        base = self.base()
        matched = base + like(1, 2, 703)
        checks = [
            (base, 1, 1, "t"), (base, 1, 2, "t"), (base, 4, 1, "t"),
            (matched, 1, 2, "t"), (matched, 2, 1, "t"),
            (base, 1, 3, "t"), (base, 2, 3, "t"),
            (base, 1, 5, "f"),
            (base + call(1, "block_account('%s')" % uuid(2)), 1, 2, "f"),
            (released_group(1, 2, delay=2), 1, 2, "f"),
            (base + premium(1), 1, 2, "t"),
            (matched + call(1, "disconnect_pair('%s','%s')" % (uuid(2), uuid(704))), 1, 2, "f"),
        ]
        for sql, v, o, want in checks:
            with self.subTest(viewer=v, owner=o, want=want):
                self.assertEqual(db().run(sql + "select app.can_view_photos('%s','%s');" % (uuid(v), uuid(o)))[-1], [want])

    def test_purge_discovery(self):
        sql = (self.base() + call(1, "likes_you()") + call(1, "start_discovery_session()")
               + "update like_preview set expires_at = now() - interval '1 second'; update discovery_session set expires_at = now() - interval '1 second';")
        rows = db().run(sql + "select app.purge_discovery(); select count(*) from like_preview; select count(*) from discovery_session;")
        self.assertEqual(rows[-3:], [["3"], ["0"], ["0"]])

    def test_privileges(self):
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run("set local role anon; select public.likes_you();")
        with self.assertRaisesRegex(SqlError, "permission denied"):
            db().run(as_user(uuid(1), "select app.is_premium('%s');" % uuid(1)))
```

  Note on `test_can_view_photos`: with `base`, pairs (1,2) and (1,3) carry likes *from* 2 and 3 towards 1; (1,2) is still a candidate for both sides, so `(base, 1, 2)` is true through the candidate rule, not premium. The premium-only case is `(base + premium(1), 1, 2)` after 1 has passed 2: add `passes(1, 2, 705)` to that row's SQL so the candidate rule no longer applies, and add the matching free row `(base + passes(1, 2, 705), 1, 2, "f")`.
- [ ] **Step 2: Run** `cd supabase/tests && python3 -I -m unittest test_likes_you` → errors `function public.likes_you() does not exist`.
- [ ] **Step 3: Write `0013_likes_you.sql`**:
  - `app.is_premium(acct uuid) returns boolean language sql stable`: exists entitlement row per spec.
  - `app.incoming_likes(me uuid) returns table (pid uuid, other uuid)`: pairs with `me in (a, b)`, `app.candidate(me, id)`, a `pair_like` from the other, none from `me`, no `pair_pass` by `me`.
  - `create table like_preview (token uuid pk default gen_random_uuid(), viewer uuid references account(id) on delete cascade, pair_id uuid references pair(id), created_at timestamptz default now(), expires_at timestamptz not null default now() + interval '24 hours', unique (viewer, pair_id))`; RLS enabled, no policy; `revoke all on like_preview from anon, authenticated`.
  - `public.likes_you() returns jsonb`: `me := app.uid()`; collect `app.incoming_likes(me)`; if `app.is_premium(me)` return cards ordered by `hashtextextended(pid::text, 0)`; else upsert one `like_preview` per pair (`on conflict (viewer, pair_id) do update set expires_at = excluded.expires_at`) and return `previews` of `{"token", "age"}` in the same order. Both shapes carry `outcome`, `premium`, `count`.
  - `app.can_view_photos(viewer uuid, owner uuid) returns boolean`: `viewer = owner`, or the pair exists and (`matched_at is not null and app.pair_open(id)`, or `app.candidate(viewer, id)`, or `app.is_premium(viewer) and exists incoming like from owner in app.incoming_likes(viewer)`).
  - `app.purge_discovery() returns int`: delete expired rows from both tables, return the sum.
  - cron block: `cron.schedule('purge-discovery', '41 3 * * *', 'select app.purge_discovery()')` when pg_cron exists.
  - Revokes/grants per Global Constraints.
- [ ] **Step 4: Run** the likes tests, then the full suite → `OK`.
- [ ] **Step 5: Commit** `feat(backend): Likes You eligible set, preview tokens, photo access rule`.

### Task 4: Docs, Supabase apply, verification

**Files:**
- Modify: `supabase/README.md` (rows for 0012, 0013; a "Phase 5b RPCs" paragraph listing the five RPC signatures and their outcomes), `docs/superpowers/plans/decision-log.md` (new entry "2026-10-26 — Discovery and Likes You (Phase 5b), engineering": the calls from the spec, what moved to 5c/5d, owner to-do for Twilio Verify).

- [ ] **Step 1: Write the README rows and paragraph; append the decision-log entry.**
- [ ] **Step 2: Apply 0011, 0012, 0013 to the Supabase project** with the MCP `apply_migration` tool, in order, names equal to the file stems.
- [ ] **Step 3: Verify on Supabase**: `select jobname from cron.job order by 1` lists `purge-discovery`, `purge-location-samples`, `purge-void-encounters`, `release-due-encounters`; `has_function_privilege('authenticated','app.candidate(uuid, uuid)','execute')` is false; `get_advisors(security)` shows no new WARN beyond the intentional security-definer RPC notices.
- [ ] **Step 4: Commit** `docs(backend): Phase 5b notes; applied to Supabase` and push.
