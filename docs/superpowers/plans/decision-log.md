# rast decision log

Product decisions come from the handoff. Entries here are engineering choices made while building, each reversible.

## 2026-10-20 — Toolchain

- Flutter 3.47.7 stable (framework abaf9c5237, engine deb287481e), Dart 3.13.5, installed at `~/development/flutter`.
- Android SDK at `~/Android/Sdk`: platforms android-35, android-36; build-tools 35.0.0, 36.0.0; command-line tools 11076708. OpenJDK 21.
- No Xcode on this machine: iOS is configured but not built here.

## Dependencies (resolved by `flutter pub add` on 2026-10-20)

| Package | Version | Why |
| --- | --- | --- |
| flutter_riverpod | 3.4.3 | app state + dependency injection, plain `Notifier` classes, no codegen |
| go_router | 18.1.1 | declarative routes, `StatefulShellRoute` for the four tabs, one redirect guard |
| shared_preferences | 2.5.6 | device-local appearance, timing, notifications, intro status, mock safety and session |
| image_picker | 1.2.4 | gallery picker for the four photos |
| flutter_svg | 2.3.0 | the 36 handoff icons, tinted with `ColorFilter` |

## Engineering choices

- The Flutter project lives at the repository root; the handoff stays in `rast-flutter-handoff/` untouched.
- Icons are tinted with a `srcIn` colour filter rather than editing the SVGs, so the handoff files stay byte-identical.
- The variable font is declared once as family `PlusJakartaSans`; weights are selected with `FontVariation('wght', n)` plus the nearest `FontWeight` bucket for engines that ignore variations.
- Mock OTP `246810` is only known to `MockAuthRepository`.
- Self-described identities match only the "Everyone" interest (prototype behaviour). Marked provisional: the handoff says not to guess a mapping.
- Prototype age guard 18–130 kept for the mock. Production age model is an open product decision.

## 2026-10-24 — Owner decisions for Phase 0 and Phase 5

Product decisions, given by the owner in conversation. Not reversible by engineering choice.

- **Backend:** Supabase (PostgreSQL + PostGIS, Auth, Storage, Realtime). Chosen for built-in PostGIS and phone OTP integration. Engineering detail follows below.
- **Age input:** the user enters their **full birth date**, never an age. Age is derived on the server from the date and the server's UTC date, so the 18 check is exact. The display rule (ages 99 and above show as 99+) is unchanged. Decided 2026-10-24 after the owner first proposed birth year only; a year alone cannot prove 18 within the birthday year.
- **Raw location sample retention:** 24 hours after server receipt, then deleted. Accepted encounters keep no coordinates.
- **Markets:** Turkey and abroad from day one. SMS provider must deliver to Turkish and international numbers; KVKK and GDPR both apply.
- **Devices for Phase 0:** Pixel 9a plus a second Android phone (owner), and a Mac with an iPhone for iOS measurements.
- **Pending encounters when a delay setting changes:** confirmed by the owner 2026-10-24. The original release floor is kept. If a participant increases their delay, the release time may move later. Reducing a delay never reveals an unrevealed encounter before its floor. Rationale: otherwise one person could shorten their delay after a crossing and defeat the privacy the other chose.

## 2026-10-24 — Engineering choices for Phase 5 (proposed, reversible)

- **SMS/OTP:** Supabase Auth phone sign-in with **Twilio Verify** as the provider. Fastest to set up, covers Turkey and international numbers, and Supabase has a native integration. Alphanumeric sender IDs in Turkey need registration; use a numeric sender until then. Revisit if Turkish delivery cost or latency is poor.
- **Location storage:** PostGIS `geography(Point, 4326)` column with a GiST index on a time-partitioned `location_sample` table (sample id, account ref, point, horizontal accuracy, observed UTC, received UTC, sequence). Candidate pairs via `ST_DWithin(…, 20)` within the time window, decided by `ST_Distance` plus accuracy, eligibility and tombstone checks in a server function. Accepted encounters go to `encounter` (pair id, encounter UTC, rule version, release floor, state) with no coordinates. Row-level security hides raw samples from clients; a scheduled job deletes samples older than 24 h. what3words and vector databases were considered and rejected: neither answers a 20-metre distance question, and what3words would send raw coordinates to a third party.
- **Device buffer:** pending samples in a small local SQLite queue (drift), uploaded in batches, deleted on acknowledgement. No location history on the device.
- **Open until Phase 0 measures them:** max sample age / clock skew window, accuracy threshold, moving vs stationary evidence, encounter deduplication.

## 2026-10-24 — Location lab dependencies (labs/location_lab, resolved by `flutter pub add`)

| Package | Version | Why |
| --- | --- | --- |
| geolocator | 14.1.2 | position stream; Android foreground service via `ForegroundNotificationConfig`; iOS background updates via `AppleSettings` |
| permission_handler | 13.0.2 | request background location ("Allow all the time") and notifications |
| sqflite / sqflite_common_ffi | 2.4.5 | local rows for sessions, samples, events; ffi build runs the same store in `flutter test` |
| battery_plus | 7.1.2 | battery percent and charging state per sample |
| device_info_plus | 13.3.0 | model and OS version in the session row |
| path_provider, share_plus | 2.1.6, 13.3.1 | export directory and share sheet |
| ntp | 2.0.0 | clock offset at session start |
| uuid, intl, flutter_riverpod | 4.6.0, 0.20.3, 3.4.3 | ids, time formatting, state |

## 2026-10-25 — Phase 0 first run (Pixel 9a)

Setup: Pixel 9a (Android 17, SDK 37), lab 0.1.0 debug build installed over adb, all three permissions granted, 30 s · High, Start pressed at 08:43 local, screen locked with the power key, phone on a desk indoors, **USB-powered the whole time** (battery drain not measurable). Pulled after 11 minutes with `adb exec-out run-as app.rast.location_lab cat app_flutter/lab.db` and converted with `labs/location_lab/tools/db2export.py` because the phone has a PIN lock and Stop/Export could not be pressed over adb; the session is still open on the phone.

Report (`python3 labs/location_lab/tools/analyze.py single labs/location_lab/exports/pixel9a-T10-20261025`):

- Samples: 22 over 11.1 min; intervals median 31.0 s, p90 34.0 s, p99 44.0 s, max 44.0 s; outages: none.
- By lifecycle: resumed 3 samples (median 30.4 s), paused 19 samples (median 31.0 s, p90 42.0 s). Sampling continued unchanged while the screen was locked and the device reported Dozing.
- Accuracy: median 59.2 m, p90 98.5 m, worst 132.7 m; 1 of 22 samples ≤ 20 m. Indoors, so expected; no conclusion for the 20 m radius yet.
- Sample age (device clock − fix time): median 0.1 s, p90 0.2 s.
- NTP offset at start: −3080 ms. Cross-checked: the phone clock was 3.2 s ahead of the host even with automatic time on. Pair analysis must keep using the NTP correction.
- Foreground service stayed up (`isForeground=true`, geolocator channel) for the whole run.

What this run settles: the pipeline works end to end (permissions, foreground service, locked-screen sampling, storage, analysis). What it does not settle: battery drain and accuracy outdoors, both need the PROTOCOL runs on battery.

Observation: after the power key the app logged paused → resumed → paused within a minute (screen woke once before timing out). Harmless, but note it when reading lifecycle tables.

### Second phone: Nothing Phone (2a), model A059, Android 16 (SDK 36)

Installed 2026-10-25 over adb after the owner enabled USB debugging. All three permissions granted and shown as Precise/Always/Notifications. Sanity run, 30 s · High, app in the foreground then screen off: 5 samples in 1.4 min, intervals median 30.5 s, max 32.5 s, foreground service up, Stop ended the session cleanly. NTP offset −1047 ms. Nothing OS battery restrictions were not touched (no whitelist entry), so R5 will measure the stock behaviour. Both Android phones are now ready for the PROTOCOL runs.

## 2026-10-25 — Birth date in the mock app (engineering)

Implements the 2026-10-24 product decision. `Profile.age` is gone as a stored field; `Profile.birthDate` (UTC calendar date) is stored as `rast.profile.birthDate` = `YYYY-MM-DD`, and `Profile.age` is a getter using `ageOn(birthDate, today)` in `rules.dart` (completed years, birthday inclusive, 29 February counts on 1 March). The About you page takes day / month / year in three numeric fields rather than a date picker: typing is faster than scrolling a hundred years, and it is testable. Validation order: not a real calendar date → "Enter your birth date as day, month and year."; future date or older than 130 → "Enter a valid birth date."; under 18 on the device's UTC date → the existing 18+ message. Old installs lose the stored age and are sent back to About you by the setup check; acceptable for a mock. Mock people keep plain ages because they stand in for server-provided profiles. 87 Dart tests.

### 2026-10-25 — Nothing Phone (2a) locked-screen run

Same setup as the Pixel run (30 s · High, Start then power key, desk indoors), but on battery, 74 %. The owner pressed Stop after 26.3 min; the session closed cleanly (`stopped` event, service gone). Report: 52 samples, intervals median 30.0 s, p90 31.8 s, max 56.0 s, no outages, all but one sample in `paused`; accuracy median 17.6 m, p90 25.6 m, worst 35.9 m; sample age p90 1.8 s; battery drain 0.0 %/h (the phone turned out to be charging over USB, so no battery conclusion); NTP offset −1022 ms. Nothing OS did not throttle the foreground-service stream at 30 s on a locked screen in this window. R5 (battery saver) still needed.

## 2026-10-25 — Backend core (Phase 5a), engineering

Built under `supabase/` as eight plain SQL migrations, proven by 55 Python tests against a local `postgis/postgis:17-3.5` container (no Supabase account needed; `supabase/README.md`). Spec: `docs/superpowers/specs/2026-10-25-backend-core-design.md`.

- **Provisional thresholds** in `encounter_params`, to be replaced after Phase 0: radius 20 m (product rule), max skew between the two samples 60 s, max sample age 24 h (offline uploads inside the retention window still count), max future 60 s, max accuracy 50 m (the largest radius the lab's sensitivity table uses).
- **Distance rule:** centre to centre, PostGIS spheroid distance rounded to millimetres, `<= 20.000` passes and `20.001` fails. Accuracy is a gate only; it is not subtracted from the distance.
- **One live encounter per pair:** a partial unique index; repeated crossings while one is pending or released add nothing; after a void a new one can be created. Encounter time is the later of the two samples.
- **Encounter times are hidden** from clients at the column-privilege level (`encountered_at`, `release_at` are not selectable by `authenticated`); raw samples are not readable by clients at all.
- **Blocks are silent:** block/unblock write no `pair_event` and create no pair row, so the blocked person cannot infer it; blocking a match removes the connection with the ordinary `disconnected` event.
- **delete_account** voids every live encounter of the account and hides the profile; pairs and tombstones remain, so "never again" holds for the account pair (SAFE-14 scope).
- **No partitioning** of `location_sample` yet: a plain table with GiST + time indexes and an hourly purge. Revisit if volume demands it.
- **Review fixes (fresh reviewer, 2026-10-25):** a pair and its encounter are invisible to clients until the encounter is released or the pair is matched (`app.pair_visible`), and `created_at` is not readable on either; a like writes no event and `pair_like` shows only the caller's own likes, so a free member cannot learn who liked them; intake takes advisory locks on the ~1 km grid cell and its neighbours so overlapping uploads still pair; clients cannot delete their rows or change `account.status`; a deleted account's open connections close like a disconnect and messaging to or from it is unavailable; the delay trigger runs as owner so clients can change their delay; PostGIS is created in the `extensions` schema.
- **Not yet in place (Phase 5b):** discovery sessions and cursors, media derivatives for Likes You, Edge Functions, Twilio Verify, Flutter adapters, a scheduled call of `release_due_encounters`.

## 2026-10-26 — Supabase project live; Discovery and Likes You (Phase 5b), engineering

Project `tmgpzujqdninoavcalto`, migrations applied through the Supabase MCP server (no CLI on the dev machine); pg_cron enabled. Two Supabase-only findings fixed the same day: `alter default privileges … in schema app` stores nothing on Supabase, so `0009` revokes execute on `app` functions explicitly and every later migration repeats the blanket revoke; `0010` pins `search_path` on every `app` function (advisor 0011). Rule for new `app` functions: set `search_path` and expect the blanket revoke at the end of the migration.

Phase 5b was started without a question round (owner: "yapılması gerekenleri yap, sonra 5b'e başla"). Calls, all reversible, spec `docs/superpowers/specs/2026-10-26-discovery-design.md`, 23 new tests (87 total):

- **Release:** pg_cron runs `app.release_due_encounters()` every minute; a released person appears at most 60 s after `release_at`, never before.
- **Deck order:** `hashtextextended(seed || pair_id)`; one session per account, 24 h expiry, cursor = last order key. Candidates released behind the cursor join on the next session; removals never skip a card. No eligibility revision on the session: every page re-evaluates.
- **Card:** `account_id`, age, gender only when `show_gender`, four photo paths. No timestamps, distance or like status.
- **Pass:** per pair, permanent until rewound, private (no event, no revision). Rewind restores only the most recent pass and only if that person is still a candidate; otherwise nothing changes. Not entitlement-gated.
- **Likes You:** eligible set = candidates who liked the caller, computed before any entitlement logic. A pass does not remove a liker from it (fresh review, 2026-10-26: with the exclusion, pass + count + rewind would name every liker to a free member in 3N calls). Free members get a count and `{token, age}` previews ordered by token (age because the mock's locked card shows it); premium members get full cards. Tokens live 24 h and are reused. The RPC writes tokens, so clients must POST it.
- **Photo access rule:** self, open match, or current candidate (`app.can_view_photos`, security definer and callable by `authenticated` so a Storage policy can use it). A "premium with incoming like" clause was dropped as unreachable: every eligible liker is already a candidate, and likers appear in Discover as ordinary cards; what Likes You protects is the fact of the like, not the photos.
- **Review minors deferred (0014 fixed the four important findings):** `discovery_session.seed` is selectable by its owner (harmless, could be column-restricted); two concurrent `start_discovery_session()` calls can leave two rows until the purge; a repeated pass keeps the first `created_at`; a cursor from an old session is accepted against a new seed (client bug only); `app.card` returns null without a profile row (unreachable through `candidate`); the plpgsql variable `out` in `discovery_cards` could be renamed.
- **Moved to 5c:** Storage bucket and policy on `app.can_view_photos`, the blurred derivative and the Edge Function that resolves a preview token, Twilio Verify (owner: create a Twilio Verify service and enter its SID/token under Authentication → Phone in the dashboard). **5d:** Flutter adapters for the RPCs.
