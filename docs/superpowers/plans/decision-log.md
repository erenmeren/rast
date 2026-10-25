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
