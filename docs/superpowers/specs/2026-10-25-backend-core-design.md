# Backend core (Phase 5a) design

Date: 2026-10-25. Owner decisions it relies on: Supabase + PostGIS, full birth date, 24 h raw-sample retention, the confirmed delay-change policy (decision log 2026-10-24). Handoff sources: docs/04 §3, §4, §6, §8; docs/05 RULE, DELAY, SAFE rows.

## Goal

The server-authoritative core that every production adapter will call: the schema, the location-sample intake with encounter evaluation, the reveal-delay policy, the transactional pair operations (like, match, disconnect, block, report, message) and the retention job. All of it as plain SQL migrations under `supabase/migrations/`, provable locally against a PostGIS container with no Supabase account.

## Non-goals

- Discovery sessions, cursors, media derivatives and Likes You presentation (Phase 5b).
- Flutter adapters, Edge Functions, Twilio Verify wiring (Phase 5b/5c).
- Final numeric thresholds. They are parameters seeded with provisional values and changed after Phase 0.
- Partitioning of `location_sample`. A plain table with a 24 h purge is enough until volume says otherwise.

## Layout

```
supabase/
  migrations/           0001_extensions.sql … one concern per file, applied in order
  tests/                Python unittest (stdlib) driving psql inside a docker container
  tests/auth_stub.sql   test-only auth.users + auth.uid() so the plain PostGIS image behaves like Supabase
  README.md             how to run the tests, how to apply to a Supabase project
```

Schemas: `public` holds tables and the RPC functions clients may call. `app` holds internal helpers and the evaluation logic; it is not exposed through the API. Every public table has RLS enabled. The `authenticated` role gets only the policies listed below; the `anon` role gets nothing.

## Tables

| Table | Columns and rules |
| --- | --- |
| `account` | `id uuid pk references auth.users`, `status account_status (active, deleted)`, `created_at`, `deleted_at`. The phone number stays in `auth.users`. |
| `profile` | `account_id pk`, `birth_date date not null`, `gender gender_identity (woman, man, nonbinary, self)`, `custom_gender text default ''`, `show_gender bool`, `visible bool default true`, `revision bigint`, `updated_at`. Check: `custom_gender <> ''` when gender is `self`. |
| `photo` | `id uuid pk`, `account_id`, `slot int check 0..3`, `storage_path text`, `state photo_state (uploading, ready, removed)`, `created_at`. Unique `(account_id, slot)` where state <> 'removed'. |
| `preferences` | `account_id pk`, `interests interest[] not null` (everyone, women, men, nonbinary; non-empty; `everyone` alone or absent), `min_age int`, `max_age int` (18..99, min <= max, 99 means open-ended), `interval_s int` in (15,30,45,60,75,90,105,120) default 30, `delay_hours int` in (0,1,2,4,6,12,18,24) default 2, `updated_at`. |
| `intro_progress` | `account_id pk`, `content_version int`, `completed_at timestamptz`. |
| `device` | `id uuid pk`, `account_id`, `platform text`, `created_at`, `last_seen_at`. |
| `location_sample` | `id uuid pk`, `account_id`, `device_id`, `seq bigint`, `point geography(Point,4326)`, `accuracy_m real`, `observed_at timestamptz`, `received_at timestamptz default now()`. Unique `(device_id, seq)`. GiST on `point`, btree on `(account_id, observed_at)`, btree on `received_at`. No client policy at all: clients write through the RPC and never read. |
| `encounter_params` | Single row (`id bool pk default true check (id)`): `radius_m` 20, `max_skew_s`, `max_sample_age_s`, `max_future_s`, `max_accuracy_m`, `rule_version int`. Provisional seed values are listed in the migration and the decision log. |
| `pair` | `id uuid pk`, `a uuid`, `b uuid` with `a < b`, unique `(a, b)`, `revision bigint default 0`, `matched_at timestamptz`, `disconnected_at timestamptz` (the permanent tombstone), `created_at`. |
| `pair_like` | `pair_id`, `from_account`, `created_at`; pk `(pair_id, from_account)`. |
| `block` | `blocker`, `blocked`, `created_at`; pk `(blocker, blocked)`. |
| `encounter` | `id uuid pk`, `pair_id`, `encountered_at timestamptz`, `rule_version int`, `release_at timestamptz`, `state encounter_state (pending, released, void)`, `sample_a uuid`, `sample_b uuid` (ids only, samples are purged), `created_at`. Partial unique on `pair_id` where state <> 'void': one live encounter per pair; a later crossing while one is live is not a new row. |
| `message` | `id uuid pk`, `pair_id`, `sender`, `client_op_id uuid`, `seq bigint`, `body text`, `created_at`. Unique `(pair_id, client_op_id)`; unique `(pair_id, seq)`. |
| `report` | `id uuid pk`, `reporter`, `target`, `pair_id null`, `reason_code text`, `status report_status (received, reviewing, closed)`, `client_op_id uuid unique`, `created_at`. No narrative column in this phase. |
| `entitlement` | `account_id`, `product text`, `status text`, `valid_until timestamptz`, `verification_revision bigint`; pk `(account_id, product)`. Written only by service role. |
| `pair_event` | `id bigserial pk`, `pair_id`, `revision bigint`, `kind text`, `created_at`. The outbox: every pair-changing transaction appends one row in the same transaction. |

Policies for `authenticated`: own-row select/insert/update on `account`, `profile`, `photo`, `preferences`, `intro_progress`, `device`; select on `pair`, `pair_like`, `encounter` (only `state`, never `encountered_at` or `release_at`: those two columns are revoked from `authenticated`), `message`, `pair_event` where the caller is `a` or `b`; select on own `block` rows and own `report` rows; select on own `entitlement`. All writes to `pair`, `pair_like`, `block`, `encounter`, `message`, `report`, `location_sample` go through the RPC functions below, which run as `security definer`.

## Helpers (`app` schema)

- `app.age_on(birth date, today date) int`: completed years, birthday inclusive, 29 February counts on 1 March.
- `app.uid() uuid`: `auth.uid()` or raises `not_authenticated`.
- `app.pair_for(x uuid, y uuid) uuid`: returns the pair id, inserting the row with `(least, greatest)` when missing.
- `app.setup_complete(account uuid) bool`: account active, profile present, age >= 18, gender set (custom text when self), preferences present and non-empty, four `ready` photos, `visible`.
- `app.mutual_preferences(x uuid, y uuid) bool`: each one's gender fits the other's interests (`everyone` fits all; `self` fits only `everyone`) and each one's age is inside the other's range (max 99 = open).
- `app.pair_open(pair uuid) bool`: no tombstone and no block in either direction.
- `app.eligible_pair(x uuid, y uuid) bool`: setup_complete for both, mutual_preferences, pair_open.
- `app.effective_delay_hours(x uuid, y uuid) int`: `greatest` of the two `delay_hours`.

## Location intake and encounter evaluation

`public.submit_location_samples(samples jsonb) returns jsonb`, caller = `app.uid()`. Input: array of `{id, device_id, seq, lat, lon, accuracy_m, observed_at}`. Per sample, in order:

1. Reject with a reason code when: malformed; `observed_at` older than `now() - max_sample_age_s` (`too_old`); later than `now() + max_future_s` (`future`); `accuracy_m > max_accuracy_m` (`inaccurate`); `(device_id, seq)` already stored (`duplicate`, counted as accepted idempotently); device not owned by the caller (`device`).
2. Insert the row.
3. `app.evaluate_encounters(sample_id)`.

Returns `{"accepted": [ids], "rejected": [{"id":…, "reason":…}]}` and nothing about other people.

`app.evaluate_encounters(sample uuid)`: for the new sample S of account A, select samples T of other accounts with `ST_DWithin(S.point, T.point, radius_m)` and `|S.observed_at - T.observed_at| <= max_skew_s` and `T.accuracy_m <= max_accuracy_m`; keep the pairs where `ST_Distance(S.point, T.point) <= radius_m` (centre to centre, 20 m exactly passes, 20.001 fails); for each distinct account B, if `app.eligible_pair(A, B)`, insert an `encounter` for `app.pair_for(A, B)` with `encountered_at = greatest(S.observed_at, T.observed_at)`, `release_at = encountered_at + effective_delay_hours`, `state = pending`, `rule_version` from params. `on conflict do nothing` against the live-encounter index. Accuracy is a gate only; it does not shrink the distance (the optimistic-distance idea from the lab stays an analysis tool until Phase 0 says otherwise).

`app.release_due_encounters()`: sets `state = released` where `state = pending and release_at <= now()`. Discovery (5b) reads only `released` rows and re-checks `app.eligible_pair` at delivery.

## Delay policy

Trigger on `preferences` when `delay_hours` changes: for every pending encounter of that account, `release_at = greatest(release_at, encountered_at + new effective delay)`. Reductions never move `release_at` earlier; increases extend it. `released` rows are untouched.

## Pair operations (public RPCs, caller = `app.uid()`, `security definer`)

Every function locks the pair row (`select … for update`), checks the tombstone and blocks inside the lock, writes, bumps `pair.revision`, appends a `pair_event`, and is idempotent on `client_op_id` where it takes one.

- `like_account(target uuid, client_op_id uuid) returns jsonb {outcome: liked | matched | unavailable}`: requires a `released` encounter for the pair and `app.eligible_pair`; inserts the like; when the reverse like exists sets `matched_at` (once) and returns `matched`. A closed pair returns `unavailable` without side effects.
- `disconnect_pair(target uuid, client_op_id uuid) returns jsonb {outcome: disconnected}`: sets `disconnected_at` (idempotent), voids live encounters, appends `pair_event kind = disconnected`. Works when no match exists.
- `block_account(target uuid)`: inserts the block; when the pair is matched, also disconnects in the same transaction (SAFE-09 semantics). `unblock_account(target uuid)` deletes only the block row; the tombstone stays (SAFE-06).
- `send_message(target uuid, client_op_id uuid, body text) returns jsonb {outcome: sent | unavailable, seq}`: requires `matched_at` and an open pair; `seq = max + 1` under the lock; same `client_op_id` returns the same row.
- `submit_report(target uuid, reason_code text, client_op_id uuid, also_block bool) returns jsonb {outcome: received}`: inserts the report; `also_block` runs `block_account` in the same transaction. Reporting a removed connection is allowed.
- `delete_account()`: marks the account deleted, hides the profile, voids its pending encounters; pairs and tombstones remain (SAFE-14 scope: account pair only).

## Retention

`app.purge_location_samples()`: `delete from location_sample where received_at < now() - interval '24 hours'`. `app.purge_void_encounters()`: void rows older than 30 days. A migration schedules both with `pg_cron` when the extension exists (hourly / daily); tests call the functions directly.

## Tests

Python `unittest` in `supabase/tests/`, stdlib only. A module-level fixture starts `postgis/postgis:17-3.5` with docker (random host port, `POSTGRES_PASSWORD=test`), waits for readiness, applies `tests/auth_stub.sql` then every migration in order with `psql -v ON_ERROR_STOP=1` inside the container, and removes the container at the end. Each test runs inside a transaction that is rolled back, with `set local role authenticated` and `set local request.jwt.claim.sub` to act as a given account.

Scenarios the suite must cover, each mapped to the criteria row it proves:

- RULE-01/02/03: 20.000 m passes, 20.001 m and 35 m fail, negative accuracy is rejected.
- RULE-04: underage, hidden, three photos, blocked, disconnected, outside the other's age or interest filters: no encounter.
- RULE-05: sample older than `max_sample_age_s`, skew beyond `max_skew_s`, accuracy above `max_accuracy_m`: no encounter, and the rejection reason is reported.
- Self-described gender matches only `everyone`.
- Delay: `release_at = encountered_at + max(delayA, delayB)`; a reduction leaves `release_at`; an increase extends it; a released row is untouched. `release_due_encounters` flips at the boundary.
- One live encounter per pair; a second crossing adds no row; after `void` a new one can be created.
- SAFE-02/03: disconnect then like, match and message all return `unavailable`; a second disconnect with the same op id returns the same outcome; `pair.revision` increases once.
- SAFE-06/07: block then unblock keeps the tombstone when matched, and keeps eligibility possible when unmatched.
- SAFE-09: report with `also_block` on a match blocks and disconnects atomically.
- Messages: `seq` is dense per pair; a retried `client_op_id` returns the original `seq`.
- Intake: duplicate `(device_id, seq)` is accepted once; a device of another account is rejected; the response contains no other account id.
- RLS: as `authenticated`, `select from location_sample` returns no rows for anyone; `encountered_at` and `release_at` are not selectable; a pair the caller is not part of is invisible.
- Retention: samples older than 24 h are purged, newer ones stay.

## Gate

All scenarios above pass locally. The migrations apply cleanly to a fresh Supabase project (owner creates the project; applying is one `supabase db push`). Provisional threshold values are listed in the decision log as "to be replaced after Phase 0". Phase 5b starts from this schema.
