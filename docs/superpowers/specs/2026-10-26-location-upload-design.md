# Location sampling and upload (Phase 5e) design

Date: 2026-10-26. Engineering calls without a question round (owner: "bitir eksik kalan şeyleri"). Builds on the Phase 0 lab (`labs/location_lab`, locked-screen sampling proven on Pixel 9a and Nothing Phone 2a) and the 5a intake RPC `submit_location_samples`.

## Goal

The app records the member's position at the chosen interval, also with the screen locked, and uploads it in small batches so the server can find crossings. Nothing about other people ever comes back from the upload.

## Non-goals

iOS field validation (no device here; the Info.plist keys and `AppleSettings` are set as in the lab), battery tuning beyond the lab's defaults, moving/stationary heuristics, a visible sample history on the device.

## Shape

- `LocationRepository` (new interface): `hasPermissions()`, `requestPermissions()` (precise location, then background, then notifications, in that order), `fixes(intervalSeconds)` (a stream of `Fix(lat, lon, accuracyM, observedAt)`), `deviceId()` (the `device` row for this install, created once and remembered in the store), `upload(samples)` → accepted ids.
- Mock: permissions granted, no fixes, uploads accepted. Supabase: `permission_handler` + `geolocator` as in the lab (foreground service notification "rast is finding crossings nearby"), `device` insert under RLS, `submit_location_samples` RPC.
- `LocationService` (`locationProvider`, app state): runs while the session is active and location is enabled; restarts the stream when the interval setting changes; queues samples (`id`, `seq`, `lat`, `lon`, `accuracy_m`, `observed_at`) in memory and in the store (`rast.location.queue`, newest 500); flushes every 5 samples or 60 s and on resume; a failed flush keeps the queue; `seq` is a persisted counter per install. Status (`running`, `lastFixAt`, `pending`, `lastError`) is shown on the location settings page.
- Permission page "Enable location": requests the permissions; a refusal finishes setup with location off and a toast. Settings toggle "Location access" asks again when turned on.
- Platform: Android manifest gets the lab's location, foreground-service and notification permissions; Info.plist gets the usage strings and `UIBackgroundModes: location`.

## Tests

Service with a fake repository: fixes become samples with increasing `seq`; flush after 5 samples sends one batch and clears it; a failed flush keeps the samples and retries on the next flush; the interval change restarts the stream; stopping cancels it. Live: `deviceId()` creates one row and returns the same id twice; one upload is accepted. Device run: the owner's phone (not connected now).
