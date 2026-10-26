# Location sampling and upload (Phase 5e) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Background position sampling at the chosen interval, batched into `submit_location_samples`.

**Architecture:** `LocationRepository` behind the boundary (mock + Supabase/geolocator), a `LocationService` notifier owning the stream, queue and flush timer, wired by session and settings state.

**Tech Stack:** geolocator 14, permission_handler 13, supabase_flutter.

**Spec:** `docs/superpowers/specs/2026-10-26-location-upload-design.md`

## Global Constraints
- Screens never import `lib/data/supabase/`; the service lives in `lib/features/location/`.
- Queue persisted in the store under `rast.location.queue` (JSON list, newest 500) and `rast.location.seq`.
- Flush: 5 samples or 60 s, and on resume.

## Review Focus
- Permission revoked mid-run: the stream errors; the service stops and shows the error (test `stream error stops the service`).
- Clock skew: `observed_at` is the fix's own UTC timestamp, never `now()` at upload (test asserts the sample carries the fix time).
- Duplicate `seq` after a reinstall: the counter restarts at 0 but the device id is new, so `(device_id, seq)` stays unique.

### Task 1: Repository, service, tests
Files: `lib/data/repositories.dart`, `lib/data/mock/mock_repositories.dart`, `lib/data/supabase/location_repository.dart`, `lib/features/location/location_service.dart`, `lib/app/{providers,bootstrap,app}.dart`, `test/features/location_service_test.dart`, `test/live/location_test.dart`, `pubspec.yaml`.
- [ ] Tests (fake repo) RED → implement → GREEN; live test.
- [ ] Commit `feat(app): background location sampling and batched upload`.

### Task 2: Permissions UI and platform config
Files: `lib/features/onboarding/location_permission_page.dart`, `lib/features/profile/location_settings_page.dart`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`.
- [ ] Widget tests on the mock keep passing; `flutter build apk --debug --dart-define=RAST_BACKEND=supabase` succeeds.
- [ ] Commit `feat(app): location permissions flow and platform config`; docs; push.
