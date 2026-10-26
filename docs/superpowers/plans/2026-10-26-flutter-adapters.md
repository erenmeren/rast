# Flutter production adapters (Phase 5d) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Flutter app to the Supabase backend behind the existing repository boundary, keeping widget tests on the mock and proving each adapter against the live project.

**Architecture:** `lib/data/supabase/` adapters + `bootstrap.dart` overrides; local store stays the synchronous cache, `hydrate()` pulls server state; server-side deck/likes/connections replace the mock eligibility when the Supabase backend is wired.

**Tech Stack:** Flutter 3.47, flutter_riverpod 3, go_router, supabase_flutter 2.x, Python harness for migration 0017.

**Spec:** `docs/superpowers/specs/2026-10-26-flutter-adapters-design.md`

## Global Constraints

- Flutter commands: `export PATH=$HOME/development/flutter/bin:$PATH ANDROID_HOME=$HOME/Android/Sdk`; tests `flutter test --timeout 90s`; live tests `flutter test test/live --tags live --timeout 120s`.
- Screens never import `lib/data/supabase/`; only `bootstrap.dart` and the live tests do.
- Supabase URL `https://tmgpzujqdninoavcalto.supabase.co` and the anon key are compile-time constants in `backend.dart` (public by design).
- Every live test signs in as `+905550000001` / `111111` and cleans what it created where it can (photos removed, passes rewound); never calls `delete_account` on the owner's account.
- Backend migration 0017 follows the 5a–5c privilege rules (blanket `app` revoke, security-definer RPCs revoked from `public, anon`, granted to `authenticated`).

## Review Focus

- OTP verify with an expired or wrong code: `verify()` returns false, no exception reaches the page (Task 1 live test).
- App start with a Supabase session but an empty local store (reinstall): `hydrate()` derives the phase from the server, so the member lands in Discover, not Welcome (Task 2 live test `hydrate_derives_phase`).
- Photo upload when the network drops after the row insert: the row stays `uploading`; a retry of the same slot removes the stale row first (Task 3: `upload` deletes any non-ready row in that slot before inserting).
- `like()` returning `matched` while the deck still shows the card: the card is removed and connections refresh before navigation (Task 5 test on the notifier with a fake repository).
- Realtime unavailable (web proxy, background): threads still refresh on app resume and after every send (Task 7).

---

### Task 1: Backend client, auth, session

**Files:**
- Modify: `pubspec.yaml` (supabase_flutter), `lib/data/repositories.dart` (`AuthRepository.signOut`), `lib/data/mock/mock_repositories.dart` (`signOut` no-op), `lib/app/bootstrap.dart`, `lib/app/providers.dart` (`backendKindProvider`), `lib/features/auth/session_notifier.dart` (`logOut` calls `signOut`), `lib/features/auth/phone_page.dart`/`verify_page.dart` (error toast on failure)
- Create: `lib/data/supabase/backend.dart`, `lib/data/supabase/auth_repository.dart`, `test/live/live_helpers.dart`, `test/live/auth_test.dart`, `dart_test.yaml` (exclude tag `live`)

**Interfaces:**
- Produces `Backend` (`client`, `functionsUrl`, `accessToken`), `backendProvider`, `BackendKind { mock, supabase }`, `backendKindProvider`, `SupabaseAuthRepository`, `signInTestUser(SupabaseClient)` helper for live tests.

- [ ] **Step 1: `flutter pub add supabase_flutter`**; add `dart_test.yaml` with `tags: {live: {skip: "needs the live project; run with --tags live"}}` … (use `exclude_tags: [live]` semantics: a `test/live/README` line explains).
- [ ] **Step 2: Live test** `test/live/auth_test.dart`: `signInWithOtp` then `verifyOTP` with the test user succeeds and `currentUser.phone` ends with `5550000001`; `verify('000000')` through `SupabaseAuthRepository` returns false. Run → fails (no adapter).
- [ ] **Step 3: Implement** `backend.dart` (`Backend.init()` calls `Supabase.initialize`, exposes `client`), `auth_repository.dart` (`sendCode` → `signInWithOtp(phone: dial+digits)`, `verify` → `verifyOTP(phone: last phone, token, type: sms)` catching `AuthException` → false, `signOut`), bootstrap: `--dart-define=RAST_BACKEND=supabase` selects Supabase; overrides `authRepositoryProvider`, `backendKindProvider`. Session: `SessionRepository` production wrapper returns `Session.signedOut` when `client.auth.currentSession == null`.
- [ ] **Step 4: Run** live test → pass; `flutter test` → all widget tests pass.
- [ ] **Step 5: Commit** `feat(app): supabase client, phone OTP auth, session wrapper`.

### Task 2: Profile, preferences, settings, intro, entitlement write-through + hydrate

**Files:**
- Modify: `lib/data/repositories.dart` (`SettingsRepository`, `BackendSync`), `lib/data/mock/mock_repositories.dart` (`MockSettingsRepository`), `lib/features/profile/settings_notifier.dart` (use the repository), `lib/app/providers.dart`, `lib/app/bootstrap.dart`, `lib/features/auth/verify_page.dart` (await `hydrate()` after verify, then invalidate)
- Create: `lib/data/supabase/profile_repository.dart` (profile, preferences, settings, intro, entitlement adapters + `SupabaseSync.hydrate()`), `test/live/profile_test.dart`

- [ ] **Step 1: Live test**: save a profile (birth 1995-03-02, woman, show gender) and preferences (women+men, 21–40), settings delay 4 / interval 60 / visible true; `hydrate()` into a fresh store reproduces them and derives `SessionPhase.active` for the test user (it has 4 ready photos); `intro complete` round-trips through `intro_progress`.
- [ ] **Step 2: Implement** per spec; `hydrate()` reads `account`, `profile`, `preferences`, `photo` (ready, by slot → `sb:` sources), `intro_progress`, `entitlement` in one `Future.wait`, writes the store, sets the phase.
- [ ] **Step 3: Run** live + widget tests → pass. **Commit** `feat(app): profile, preferences, settings, intro, entitlement adapters with hydrate`.

### Task 3: Photos

**Files:**
- Modify: `lib/data/repositories.dart` (`PhotoRepository`, `PhotoRejected`), `lib/data/mock/mock_repositories.dart` (`MockPhotoRepository` returns the path), `lib/features/onboarding/photos_page.dart` (await `upload`, show `PhotoRejected` messages), `lib/core/ui/photo_image.dart` (`sb:` and `preview:` sources via a `PhotoBytesProvider`), `lib/app/providers.dart`, `lib/app/bootstrap.dart`
- Create: `lib/data/supabase/photo_repository.dart`, `test/live/photo_test.dart`

- [ ] **Step 1: Live test**: upload a generated 640×480 JPEG to slot 3 → source starts with `sb:` and the photo row is `ready`; signed URL GET → 200; upload a 100×100 PNG → throws `PhotoRejected('too_small')` and no `uploading` row is left behind; `remove` sets the row `removed`.
- [ ] **Step 2: Implement** per spec (`upload`: delete non-ready rows in the slot, insert row, `storage.from('photos').uploadBinary`, `functions.invoke('photo-finalize')`, map 422 reasons; `signedUrl` 3600 s cached; `PhotoImage` resolves `sb:` through `Image.network(signedUrl)` and `preview:` through `Image.network(functionsUrl/like-preview?token=…, headers: {Authorization})`).
- [ ] **Step 3: Run** tests; **Commit** `feat(app): photo upload, finalize and signed-url rendering`.

### Task 4: Migration 0017 (connections, person_card, blocked_accounts, realtime)

**Files:**
- Create: `supabase/migrations/0017_connections.sql`, `supabase/tests/test_connections.py`
- Modify: `supabase/README.md`

- [ ] **Step 1: Harness tests**: matched pair → `connections()` lists one connection with the partner card and revision; after `disconnect_pair` → empty; `person_card(candidate)` ok, `person_card(stranger)` unavailable, `person_card(blocked)` unavailable; `blocked_accounts()` lists `{account_id, age}` after `block_account`; privileges (anon denied).
- [ ] **Step 2: Implement** per spec; `alter publication supabase_realtime add table pair_event` guarded by `if exists (select 1 from pg_publication where pubname = 'supabase_realtime')`.
- [ ] **Step 3: Run** harness → OK; apply with the MCP tool; **Commit** `feat(backend): connections, person_card, blocked_accounts; pair_event realtime`.

### Task 5: Discovery deck on the server

**Files:**
- Modify: `lib/core/models/person.dart` (`photos`, nullable `gender`, `customGender`, defaults for mock fields; `albumOf`), `lib/data/mock/mock_people.dart` (construct with `photos`), `lib/data/repositories.dart` (`DiscoveryRepository`, `LikeOutcome`, `CardPage`, `LikesYouResult`), `lib/data/mock/mock_repositories.dart` (`MockDiscoveryRepository` over the mock deck), `lib/features/discovery/deck_notifier.dart` (production path), `lib/features/discovery/eligibility.dart` (`backendKind` switch; `PeopleDirectory`), `lib/features/discovery/like_action.dart` (outcomes), `lib/features/discovery/discover_page.dart` (rewind result), `lib/app/providers.dart`, `lib/app/bootstrap.dart`
- Create: `lib/data/supabase/discovery_repository.dart`, `lib/features/discovery/people_directory.dart`, `test/live/discovery_test.dart`, `test/features/discovery/server_deck_test.dart` (fake repository)

- [ ] **Step 1: Tests**: fake-repository notifier test: cards load in server order; `like` → `matched` removes the card and emits a match event; `pass` then `rewind` restores the card at the top; `unavailable` leaves the deck unchanged. Live test: `startSession` + `cards` returns `outcome ok`; `likesYou()` shape.
- [ ] **Step 2: Implement** per spec.
- [ ] **Step 3: Run** all tests; **Commit** `feat(app): server-backed discover deck, like, pass, rewind`.

### Task 6: Likes You

**Files:**
- Modify: `lib/features/likes/likes_page.dart` (previews for free members, cards for premium), `lib/features/discovery/eligibility.dart` (`incomingLikesProvider`, `likesPreviewsProvider`), `lib/features/discovery/like_action.dart` (like back from Likes You)
- Create: `lib/features/likes/likes_notifier.dart`, `test/features/likes_server_test.dart` (fake repository)

- [ ] **Step 1: Tests**: free → N locked tiles with `preview:` sources and ages, no account ids in state; premium → cards; like back `matched` → navigates to match.
- [ ] **Step 2: Implement**; **Step 3: Run**; **Commit** `feat(app): Likes You from the server`.

### Task 7: Chat

**Files:**
- Modify: `lib/data/repositories.dart` (`ChatRepository`), `lib/data/mock/mock_repositories.dart` (`MockChatRepository` over seed threads), `lib/features/chat/threads_notifier.dart` (production path: load, refresh on changes/resume, send via RPC), `lib/features/chat/match_page.dart`, `lib/features/chat/conversation_page.dart` (async send, failure toast), `lib/app/providers.dart`, `lib/app/bootstrap.dart`
- Create: `lib/data/supabase/chat_repository.dart`, `test/live/chat_test.dart`, `test/features/chat_server_test.dart`

- [ ] **Step 1: Tests**: fake repository: threads load with partner cards; `send` appends on `sent` and shows a toast on `unavailable`; a `changes()` event refetches. Live: `threads()` for the test user lists its match with the owner; `send` returns `sent` with a seq; `messages` contains it.
- [ ] **Step 2: Implement** (realtime: `client.channel('pair_event').onPostgresChanges(insert, schema public, table pair_event)` → stream); **Step 3: Run**; **Commit** `feat(app): chat on pair rows, messages RPC and realtime refresh`.

### Task 8: Safety and account

**Files:**
- Modify: `lib/data/repositories.dart` (`SafetyRepository` operations), `lib/data/mock/mock_repositories.dart`, `lib/features/safety/safety_notifier.dart`, `lib/features/safety/safety_actions.dart`, `lib/features/auth/session_notifier.dart` (`deleteAccount` → RPC then sign out), `lib/features/safety/sheets/lists_sheets.dart` (blocked list from `blocked_accounts`, placeholder portrait)
- Create: `lib/data/supabase/safety_repository.dart`, `test/live/safety_test.dart`

- [ ] **Step 1: Tests**: mock still passes `profile_safety_test`; live: `report(owner, 'spam', alsoBlock: false)` → received; `block` then `blocked_accounts` contains the owner; `unblock` clears it (leaves the owner's match intact: do not disconnect).
- [ ] **Step 2: Implement**; **Step 3: Run**; **Commit** `feat(app): safety operations and account deletion via RPC`.

### Task 9: Docs

- [ ] README (app): how to run against Supabase (`--dart-define=RAST_BACKEND=supabase`), live tests; decision log entry (calls, deferrals, 5e scope); memory. **Commit** `docs: Phase 5d notes`; push.
