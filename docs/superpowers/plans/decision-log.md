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
