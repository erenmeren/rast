# Flutter production adapters (Phase 5d) design

Date: 2026-10-26. Engineering calls without a question round (owner: "devam"); all reversible, listed in the decision log. Backend contract: `supabase/README.md` (RPCs of 5a–5c). Handoff: docs/04 §2 (repository interfaces), docs/03 Phase 5, docs/05 FEED/LIKE/CHAT/SAFE rows.

## Goal

The app talks to the Supabase project instead of the mock: phone OTP sign-in, profile and photos on the server, the Discover deck, Likes You, chat, blocks/reports/removal, all through the RPCs and RLS tables that 5a–5c proved. Widget tests keep running on the mock; a separate live test suite runs the adapters against the real project with the test user.

## Non-goals

- Background location sampling and upload (Phase 5e: lifts `labs/location_lab` into the app and batches into `submit_location_samples`).
- Store purchases (Phase 6). Premium is read from the `entitlement` table; nothing writes it from the client.
- Push notifications, image caching to disk, EXIF stripping (client-side resize before upload is a 5e/6 item unless `photo-finalize` fails on a real phone photo; 12 MP passed in 3.2 s).

## Shape

```
lib/data/
  repositories.dart        interfaces (extended, see below)
  mock/                    unchanged behaviour; implements the new methods locally
  supabase/
    backend.dart           SupabaseClient holder, URL/anon key constants, `backendProvider`
    auth_repository.dart   OTP send/verify, sign-out
    profile_repository.dart  write-through to account/profile/preferences; `hydrate()` pulls into the local store
    photo_repository.dart  upload → finalize → `sb:` source; remove; signed URLs
    discovery_repository.dart  sessions, cards, like/pass/rewind, likes_you, connections, person_card
    chat_repository.dart   threads from connections + message rows; send; realtime refresh on pair_event
    safety_repository.dart block/unblock/disconnect/report/delete via RPC; state from block/report/pair rows
    entitlement_repository.dart  premium from entitlement
lib/app/bootstrap.dart     initialises Supabase, hydrates, overrides the providers (composition root only)
test/live/                 adapter tests against the real project; tag `live`, excluded by default
```

Composition stays in `providers.dart` (mock defaults) + `bootstrap.dart` overrides. Screens never know which backend is behind a provider.

## Backend additions (migration 0017)

- `public.connections()` → `{"outcome":"ok","connections":[{"pair_id","revision","card":<app.card of the other>}]}` for the caller's matched, open pairs (`matched_at not null`, `disconnected_at null`, no block either way).
- `public.person_card(target uuid)` → `{"outcome":"ok","card":…}` when `target` is a current candidate or an open match of the caller, else `{"outcome":"unavailable"}`. Used for a card the client no longer holds (deep link, cold start into a conversation).
- `public.blocked_accounts()` → `{"outcome":"ok","blocked":[{"account_id","age"}]}`. Blocked people get a placeholder portrait: `app.can_view_photos` is false for them by design.
- `alter publication supabase_realtime add table pair_event;` so clients can subscribe to inserts (RLS-filtered: `pair_event_member`).

## Models

- `Person`: `id`, `age`, `gender` (nullable; null when the member hides it), `customGender`, `photos` (four sources), `likesYou`. The mock fields `delayHours`, `hoursAgo`, `distanceMeters`, `interests`, `minAge`, `maxAge` stay with defaults for the mock eligibility code; the server never sends them. `albumOf(p)` uses `p.photos` when there are four, else the old prototype crops.
- Photo source strings: `assets/…` (bundled), an absolute file path (picked, not yet uploaded), `sb:<bucket path>` (uploaded original; rendered through a signed URL fetched with the user's JWT, cached in memory per path for 50 min), `preview:<token>` (Likes You preview; rendered by fetching `/functions/v1/like-preview?token=` with the Authorization header).
- `Thread.id` = pair id, `Thread.personId` = the other account, messages from `message` rows (`own` = sender is me, `time` = local HH:mm of `created_at`), `unread` = messages newer than the locally stored "read up to seq" per thread.
- `Session.verified` = a Supabase session exists. `SessionPhase` stays local (store) but `hydrate()` rewrites it from the server on sign-in/app start: signed-out without a session; `active` when account + profile + preferences + 4 ready photos exist and `intro_progress.completed_at` is set; `introPending` when setup is complete but the intro is not; `onboarding` otherwise.

## Repository interfaces (changes)

- `AuthRepository`: `sendCode(dial, phone)` → `signInWithOtp(phone: E.164)`; `verify(code)` → `verifyOTP(type: sms)`; new `signOut()`.
- `ProfileRepository`: unchanged shape; the Supabase one keeps the local store as cache and writes through (`account` insert-if-missing, `profile` upsert, `preferences` upsert). New `hydrate()` on a `BackendSync` object called by bootstrap and after OTP verify; it invalidates the notifiers.
- `SettingsRepository` (new, extracted from `SettingsNotifier`'s direct store use): `delayHours`, `intervalSeconds` → `preferences.delay_hours/interval_s`; `visible` → `profile.visible`; `notifications`, `locationEnabled` stay device-local.
- `PhotoRepository` (new): `Future<String> upload(int slot, String filePath)` returns the `sb:` source (insert row, upload bytes, `photo-finalize`; on `too_small`/`bad_image` throws `PhotoRejected(reason)`); `Future<void> remove(String source)`; `Future<Uri> signedUrl(String source)`.
- `DiscoveryRepository` (new): `startSession()`, `cards(sessionId, after)` → `(cards, next)`, `like(id)` → `liked|matched|unavailable`, `pass(id)`, `rewind()` → id or null, `likesYou()` → `(premium, count, previews:[(token, age)], cards)`, `connections()`, `personCard(id)`.
- `ChatRepository` (new): `threads()`, `messages(pairId)`, `send(targetId, clientOpId, body)` → `sent(seq)|unavailable`, `Stream<void> changes()` (realtime `pair_event` inserts, else never).
- `SafetyRepository`: becomes operation-based: `load()`, `block(id)`, `unblock(id)`, `disconnect(id)`, `report(id, reason, alsoBlock)`, `deleteAccount()`; `save(state)` and `clear()` go. The mock implements the operations on the store.
- `IntroRepository`: Supabase one writes `intro_progress` (content_version 1, `completed_at`) and reads it in `hydrate()`.
- `EntitlementRepository`: `isPremium()` from the store, refreshed by `hydrate()` from `entitlement`; `setPremium` is a no-op in production (the mock keeps it for the demo flag).

## State changes

- `DeckNotifier` (production): holds the server session id, the fetched cards in order, `focus`, `photoIndex`, and a local `history` for Rewind. `eligiblePeopleProvider` = the deck's cards (server already applied every gate); `incomingLikesProvider` = Likes You cards (premium) or an empty list; `likesPreviewsProvider` (new) = the free previews. The mock eligibility providers keep working when the mock is wired, selected by a `backendKindProvider` (`mock|supabase`) that bootstrap sets.
- A `PeopleDirectory` provider (id → `Person`) is filled from deck cards, Likes You cards and connections; `personById`/`isKnownPerson` read it in production and the mock list in mock mode.
- `ThreadsNotifier` (production): loads from `ChatRepository.threads()`, refreshes on `changes()` and on app resume; `send` posts and appends on `sent`; `ensureThread` becomes a refresh after a match.
- `SafetyNotifier`: calls the repository operations; local state mirrors the server after each call; `isUnavailable` keeps the client-side check.
- Like flow: `like()` outcome `matched` → refresh connections, navigate to the match page; `unavailable` → the existing toast; `liked` → toast.

## Errors

Every adapter maps `AuthException`/`PostgrestException`/function errors to a small `BackendFailure(kind)` (`offline`, `unauthenticated`, `rejected(reason)`, `unknown`). Screens show the existing toasts; a `401` signs the member out.

## Tests

- Widget tests: unchanged, mock-wired.
- `test/live/*_test.dart` (tag `live`): sign in as the test user (`+905550000001`, OTP `111111`), then per adapter: profile write-through and hydrate round trip; photo upload → `sb:` source → signed URL 200, tiny PNG → `PhotoRejected('too_small')`; discovery session + empty or non-empty deck; `likes_you` shape; connections; chat send + read; safety report. Run with `flutter test test/live --tags live`. Never run in CI without the test user.
- Harness tests for 0017.

## Owner to do before launch

Remove the test phone mapping; Twilio compliance profile; rotate the Twilio token.
