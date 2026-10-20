# 03 — Flutter implementation plan

Prepared 20 October 2026. This document plans a native Flutter/Dart rebuild of the archived rast design. It is not evidence that a Flutter application, SMS service, location service, payment integration or production backend already exists. The browser prototype's `README.md`, `dist/rules.js`, actual screens and regression checks establish the current design baseline. Read [04_ARCHITECTURE_AND_DATA.md](04_ARCHITECTURE_AND_DATA.md) for proposed boundaries and service contracts.

## 1. What is fixed, proposed and unresolved

**Agreed product baseline:** English interface; four tabs—Discover, Likes You, Chats and Profile; System/Light/Dark appearance; phone verification; explicit adult age and gender; separate inclusive dating preferences; four required photos; no name, job, religion or biography questions. The filter maximum 99 means 99+. The current prototype accepts whole-number age input from 18 to 130; retain that guard in mock parity tests while recording the production age model and upper sanity bound as an open decision. Native screens must reproduce the supplied visual direction and interactions, using Flutter widgets rather than wrapping the website in a WebView.

Encounters require a separation of at most 20 metres between people, reciprocal preferences, adult eligibility and visibility. The longer reveal preference wins: 0, 1, 2, 4, 6, 12, 18 or 24 hours, default 2. Location targets are 15, 30, 45, 60, 75, 90, 105 or 120 seconds, default 30. The word **target** matters: background delivery must be validated on devices.

Discover keeps a shuffled order independent of crossing timestamps. Eligible incoming likes may have locked previews; Premium reveals that same eligible set. Free mutual matching and chat remain available. Removing an existing connection prevents future matching permanently. Blocking an existing connection also removes it permanently; unblocking an unmatched profile remains reversible. Report-only leaves an active connection intact.

**Proposed implementation:** Riverpod for application state and dependency injection, go_router for navigation, repository interfaces for data access, and feature-based folders. These are replaceable engineering choices, not newly agreed product requirements. Flutter's official guidance recommends separating UI/data responsibilities, using repository abstractions and independently testable components; it treats architectural recommendations as adaptable guidance. Sources: https://docs.flutter.dev/app-architecture/guide and https://docs.flutter.dev/app-architecture/recommendations. Riverpod's own setup documentation is https://riverpod.dev/docs/introduction/getting_started.

**Open decisions:** backend provider, hosting region, supported OS/device range, age assurance, encounter accuracy and timing policies, data retention, media moderation, subscription products and operational support. Resolve decisions that block a phase; do not invent production services or silently turn suggestions into requirements.

## 2. Delivery sequence and dependencies

Proceed in small, runnable increments. Phase 1 visual work can run alongside Phase 0, but real encounter implementation depends on the Phase 0 result. Phases 2–4 may use explicitly labelled fake repositories until Phase 5 supplies production adapters. A successful demo does not satisfy a production acceptance gate.

### Phase 0 — Prove the location premise on real devices

Build a minimal native location experiment before promising uninterrupted 15–120-second background sampling. Apple documents background capabilities and authorization/session handling for Core Location; suspended applications do not simply keep running ordinary timers. Android documents substantially reduced delivery for background applications and separate requirements for location foreground services. Approximate location permission can also apply in the background. These constraints justify this feasibility gate; they do not establish rast's achieved performance. Sources:

- Apple background location: https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background
- Android background limits: https://developer.android.com/about/versions/oreo/background-location-limits
- Android permission behavior: https://developer.android.com/develop/sensors-and-location/location/permissions/background
- Android location foreground services: https://developer.android.com/develop/background-work/services/fgs/service-types#location

Test paired physical phones on the intended minimum and current supported OS versions, including representative Android manufacturers. Measure observed interval distributions, outages, horizontal accuracy, sample age, encounter recall, false positives and battery consumption. Include walking past one another, remaining nearby, urban streets, indoors, locked screens, backgrounding, power-saving modes, revoked/approximate permission, missing network and process termination. Record behavior after relaunch instead of assuming automatic recovery.

Compare a maintained Flutter plugin against the native capabilities it exposes; add a narrow platform adapter when necessary. Inspect the selected plugin's source and lifecycle support. Do not assume a Dart timer, periodic job or foreground-service flag overrides operating-system restrictions. Separate requested sampling, actual sample delivery and network upload cadence.

**Outputs:** reproducible device matrix, measured traces with test participants' permission, energy results, permission-state model, adapter recommendation and a feasibility decision. **Gate:** the product owner accepts measured limitations and the supported operating modes. If brief crossings cannot be detected reliably, present that finding before changing radius, cadence or detection semantics. The prototype's preferences remain targets rather than an unsupported guarantee.

### Phase 1 — Establish the native foundation and visual parity

Create a clean Flutter application with development, staging and production configuration boundaries. Select the current stable Flutter/Dart release and compatible package versions at implementation time, verify them against official documentation and publishers, and record exact resolved versions in the repository. Pin the application lockfile and document reproducible build commands. This handoff deliberately prescribes no guessed version numbers.

Build the theme, typography, spacing, buttons, fields, sheets, navigation, photo frame, range selector and message components first. Bundle Plus Jakarta Sans with the supplied license and preserve asset provenance. Map semantic colors to the light/dark design; photographs retain their original colors. Apply saved appearance before the initial screen and observe live system changes only in System mode.

Use native safe areas, keyboard insets, accessibility semantics and platform back behavior. Keep the desktop design gallery as a reference/development aid; it is not a mobile product destination. Capture native reference images at representative small/large phone sizes, both appearances and enlarged text settings.

**Outputs:** runnable native shell, component catalogue, four-tab router, fake dependency composition and visual comparison set. **Gate:** major screen structure, typography, photo crops, color roles and interaction targets match the archive without a WebView; no overflow or unusable contrast in the tested configurations.

### Phase 2 — Fast onboarding and the first introduction

Implement welcome → phone → OTP → age/gender → preferences → four photos → location choice → first introduction. Preserve numeric age entry and explicit gender selection. Self-description is required only when that identity option is selected. Keep identity and interest preferences separate. The two age handles share one track; sheet changes remain drafts until Save.

Photo work needs progress, retry, replace/remove and asynchronous slot ownership. Four usable photos are an eligibility prerequisite; incomplete uploads must not count as completed photos. Implement OTP resend/error/expiry states through an authentication interface. The prototype code `246810` is confined to an explicit demo adapter.

Both granting and deferring location lead to the required first introduction. Rebuild its five scenes natively: walking → 20-metre crossing and mutual preferences → default two-hour delay → Discover → two likes and chat. Preserve the 27.4-second required timeline, pause/resume, visible-time accounting, 100-ms maximum credited frame interval and disabled Continue until completion. Background or obscured playback cannot count. Reduced motion uses timed still scenes; optional Profile replay supports chapter selection. Pending first viewing restarts after interruption/relaunch, while completion belongs to the authenticated account. Native routing must prevent deep links or back navigation from bypassing the unfinished introduction, without trying to prevent operating-system app exit.

**Outputs:** complete native onboarding state machine, fake and service-ready adapters, upload workflow and lifecycle-aware story controller. **Gate:** invalid age, unverified phone, missing identity/preferences/photos and unfinished intro cannot enter discovery; denial remains usable; account switching cannot inherit another account's completion.

### Phase 3 — Candidate rules and the stable swipe deck

Port the pure rule fixtures to Dart while retaining server authority in the production contract. Implement photo taps, button/swipe parity, drag-versus-tap suppression, pass history, eligible Rewind and detail navigation. Preserve shuffled relative order across rebuilds, album changes, tabs and filter changes. Use cursor-based server pages without exposing crossing order.

Apply privacy gates before displaying identities or incoming-like counts. Test the 20-metre boundary, 99+ filter, every delay option, two-way preferences, visibility, four-photo state, block/disconnect and expiry responses. A locked Premium card must never obtain its full-quality original merely to blur it on the device.

**Outputs:** discovery/likes repositories, typed candidate states, deck controller and cross-language rule fixtures. **Gate:** Premium and free candidate identities differ only by entitlement presentation, not eligibility; an unavailable or removed stale detail never falls back to another profile.

### Phase 4 — Matches, chat, removal and reports

Build free mutual matching, thread lists, unread states, message composition, retries and notification navigation. Assign an operation identifier to retries so a network retry cannot duplicate a like, match or message. Subscribe to safety changes and invalidate active cards, threads and queued sends when a connection closes.

Implement Remove connection confirmation, permanent removed-pair state, reversible unmatched blocks, permanent removal when blocking an existing connection, report categories, optional details and the also-block choice. Removed connections remain reportable with no restore action. A report submission needs an honest acknowledgement; a local demo action cannot claim moderation has received it.

**Outputs:** native chat/safety flows, fake concurrent scenarios and server contract tests. **Gate:** stale screens, reconnects, retries, Rewind and purchase changes cannot revive removed connections. The production concurrency gate depends on Phase 5's atomic server implementation; client tests alone cannot prove it.

### Phase 5 — Production adapters, location processing and security

Choose the backend and identity/SMS providers through documented decisions. Implement authenticated upload, profile, encounter, discovery, match, message, report and entitlement adapters against the interfaces in document 04. Validate location observations and consent states; evaluate encounters and release times on the server. Restrict raw location and unrevealed media access, separate analytics from sensitive payloads, and define deletion/retention jobs before accumulating production data.

Build transactional pair removal, operation idempotency, event replay and reconciliation. Test simultaneous like/like/disconnect and message/disconnect requests with real database transactions. Verify access using two ordinary accounts, revoked sessions and guessed resource identifiers. Observe errors and queue lag without logging coordinates, OTPs or message bodies.

**Outputs:** staging backend, native adapters, schema/contracts, migrations, retention configuration and monitored integration environment. **Gate:** end-to-end physical-device crossings pass the accepted feasibility criteria; server privacy/safety race tests pass; offline and failed-write recovery preserves pending safety intent without claiming unsynced operations are confirmed.

### Phase 6 — Entitlements and release readiness

Replace Premium simulation with store-backed products and server-validated entitlements. Obtain prices from the selected store configuration; the archive's example prices are not commitments. Test purchase cancellation, pending payment, expiry, restore, revocation and device changes. Free matching/chat and all privacy delays continue unchanged.

Recheck current official store and platform requirements for the actual capabilities, markets and target SDKs before submission. Assign owners for report review, abuse response, account deletion, operational incidents and age assurance. Perform physical-device accessibility, energy, lifecycle and visual testing; supply store materials and support routes. Signing credentials and a release destination remain external inputs.

**Outputs:** release candidate, verification evidence, operational runbooks and an explicit remaining-issues list. **Gate:** no demo SMS, payment, identity or report-success behavior can be mistaken for a live service. Publishing is a separate release action, not part of this handoff.

## 3. Instructions to the implementing AI

Begin by inventorying the archived design and resolving Phase 0 dependencies. Keep a short decision log distinguishing product decisions from engineering choices. Use one application-state approach consistently; animation controllers and temporary form focus remain widget-owned lifecycle objects. Make repository replacements at the composition boundary rather than scattering demo flags through screens.

For each increment, deliver working code, changed-screen evidence, meaningful rule/widget/integration results and unresolved limitations. Keep version selection reproducible. Preserve the current design until a deliberate change is approved. Finish the native design milestone before describing backend-dependent functionality as production-ready.
