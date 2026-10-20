# 04 — Architecture and data contracts

Prepared 20 October 2026. Product behavior below follows the archived rast prototype; folder structure, entities, endpoints and transaction design are **implementation proposals**. No backend technology, database vendor or deployed API has been selected. Use [03_FLUTTER_IMPLEMENTATION_PLAN.md](03_FLUTTER_IMPLEMENTATION_PLAN.md) for sequencing and acceptance gates.

## 1. Native application boundaries

Use a feature-based Flutter application with separate presentation, application/domain and adapter responsibilities. Flutter's official architecture guide describes views/view models above repositories and external services; its recommendations support abstract repositories and dependency injection. This proposal applies those boundaries to rast rather than copying the website's global state object. Sources: https://docs.flutter.dev/app-architecture/guide and https://docs.flutter.dev/app-architecture/recommendations.

| Suggested area | Responsibility |
| --- | --- |
| `lib/app/` | Bootstrap, environments, dependency composition, router and authenticated shell |
| `lib/core/theme/`, `core/ui/` | Semantic light/dark tokens, typography and shared components |
| `lib/core/network/`, `core/storage/` | Authenticated transport, secure credential access, scoped cache and operation journal |
| `lib/core/platform/` | Location, permissions, lifecycle, notifications and purchase bridges |
| `lib/features/auth/`, `onboarding/`, `intro/` | Session, setup prerequisites and required/optional story modes |
| `lib/features/discovery/`, `likes/`, `profile/` | Candidate deck, incoming likes, identity, photos and preferences |
| `lib/features/chat/`, `safety/`, `premium/` | Matches/messages, pair restrictions/reports and entitlements |

Each feature can contain `presentation/`, `application/`, `domain/` and `data/` folders where needed; do not generate empty layers for their own sake. Use immutable state and typed failure/loading states. The proposed **Riverpod** layer owns screen controllers and injected repositories; **go_router** owns routes and redirects. Keep these replaceable through a recorded decision. Avoid mixing several competing application-state systems. Select stable package versions from official sources when implementation starts, then record and lock the resolved dependencies. References: https://riverpod.dev/docs/introduction/getting_started and https://docs.flutter.dev/app-architecture/recommendations.

Route guards consult session, setup and account intro state. Four tab stacks retain deck and scroll state. Detail/conversation routes retain explicit resource identifiers; missing authorization yields unavailable/Chats instead of substituting the first profile or thread. Route disposal, app backgrounding and scene visibility suspend animation controllers and subscriptions.

## 2. Repository interfaces and persistence

Define interfaces before choosing infrastructure: `AuthRepository`, `ProfileRepository`, `LocationRepository`, `DiscoveryRepository`, `MatchRepository`, `ChatRepository`, `SafetyRepository`, `IntroRepository` and `EntitlementRepository`. Expose typed commands and streams. Inject a clock, random source and platform permission adapter for deterministic tests. Demo implementations use fictional records; production implementations call authenticated services. Neither widgets nor routing code own authoritative matching rules.

Store credentials through an appropriate secure platform mechanism selected during implementation. Scope caches, operation journals and intro completion to the account; clear or detach them on account switch. Device appearance may remain a device preference. A global browser-style `introComplete` flag must not let a new account bypass first viewing.

Use a durable journal of intended operations rather than rewriting whole safety snapshots. An offline disconnect immediately hides the pair locally, remains pending until acknowledged and survives subsequent reports/refreshes. Reconcile a fresh server snapshot plus pending operations; never overwrite newer blocks, removals or reports with stale client arrays. An explicit unblock removes only that block edge. If durable writes fail, retain the pending operation in the current process and communicate the unsynced state; persistence across termination cannot then be guaranteed.

## 3. Suggested domain records

| Record | Essential fields and rules |
| --- | --- |
| Account/session | Opaque account ID, verified-phone reference, session revision, account status; phone number is private, never a public identifier |
| Profile | Adult age representation and declaration timestamp, identity category, optional self-description/display choice, four ordered ready-photo IDs. The prototype/mock uses integer age 18–130; the production age model and upper sanity bound remain an explicit decision. |
| Preferences | Interest categories, minimum age, maximum age with 99 meaning unbounded above, visibility, requested interval and reveal delay |
| Intro progress | Account ID, content version, pending/complete status, completion time; once-per-account behavior, not a new compulsory viewing after every sign-in |
| Location sample | Unique sample ID, authenticated device reference, coordinates, horizontal accuracy, observed UTC time, server receipt UTC time and sequence |
| Encounter | Internal canonical pair ID, accepted observation references, encounter UTC time, rule version, release floor and lifecycle state |
| Pair relationship | Canonical unordered account pair, directed likes/blocks, optional match/thread, permanent disconnect tombstone and monotonically increasing revision |
| Message | Server ID, client operation ID, thread ID, authenticated sender, server sequence/time, body and delivery state |
| Report | Reporter, target/pair, stable reason code, status and receipt; optional narrative/evidence governed by a separate approved policy |
| Entitlement | Account, product, status, validity and server verification revision; client purchase success is not authoritative |

Do not fabricate a birth date from an age number. Age refresh/age-assurance policy is unresolved; the prototype's numeric validation and SMS verification are not proof of adulthood. Keep gender identity and interest categories separate. Agree how self-described identities participate in matching; never infer identity or orientation from photos or free text.

The prototype saves only `{person, reason}` for fictional reports and discards optional detail text. Production receipt, restricted evidence access and retention are new decisions. Avoid silently persisting those details in preferences, analytics or general logs.

## 4. Server-authoritative encounter and reveal evaluation

Use server UTC for decision time. Device observation timestamps are inputs requiring validation, not trusted release clocks. Associate samples with the authenticated account; reject duplicate, implausibly old/future or malformed samples using a documented policy. A spatial index may select candidate pairs, followed by an actual geographic distance calculation; grid membership alone must not decide a 20-metre encounter.

An accepted encounter requires sufficiently reliable, sufficiently contemporaneous observations and a distance **≤20 metres between people**. Overlapping two 20-metre circles at 40 metres is not the rule. Both accounts must be adult-eligible, visible, complete with four usable photos and satisfy each other's age/gender preferences. Exclude either-direction blocks and every permanent pair tombstone.

The agreed delay calculation is:

```text
effectiveDelayHours = max(validDelayA, validDelayB)
revealAtUtc = encounterAtUtc + effectiveDelayHours
serveCandidate only when serverNowUtc >= revealAtUtc
```

Allowed delays are `[0, 1, 2, 4, 6, 12, 18, 24]`; default is `2`. Persist valid values explicitly. Reject invalid API settings rather than silently accepting arbitrary values; the demo helper's fallback can remain in compatibility tests. Choosing zero never shortens the other person's delay. Recheck current eligibility at feed delivery, candidate-media authorization, like creation and match creation. An entitlement cannot override a gate. Pausing discovery or losing a required photo stops new candidates; it does not itself close existing matches or chats.

**Open detection decisions:** maximum sample-age/skew window, reliability threshold, uncertain boundary treatment, stationary versus moving evidence, encounter deduplication, repeated meetings, delayed offline uploads and candidate lifetime. Do not invent a numeric GPS threshold or co-presence window. Full/precise permission is not a promise of metre-level observation quality; inspect the actual measurement and permission state. Platform accuracy references: https://developer.apple.com/documentation/corelocation/cllocationmanager/accuracyauthorization and https://developer.android.com/develop/sensors-and-location/location/permissions/background.

Also decide how changed preferences/delays affect pending encounters. A proposed conservative policy keeps the original release floor and can extend it when a participant increases their delay; reductions do not expose an unrevealed person before that floor. This is a proposal requiring a product decision, not an existing agreed rule. Exact encounter time, coordinates and personal countdowns stay off public DTOs.

## 5. Stable feed pagination and media authorization

Create a server discovery session with a random seed/order, eligibility revision and opaque cursor. Rank candidates independently of encounter timestamps. Preserve relative order through photo taps, rebuilds and tab navigation. Filtering may change membership, not reorder retained candidates. Define how newly released candidates join a session and when explicit refresh begins another session; use versioned pagination so ordering does not encode crossing chronology and inserts/removals do not produce duplicate pages or silently skipped profiles. Shuffling does not eliminate every possible timing inference.

Return only currently eligible cards, plus the next cursor. Revalidate every page; a snapshot is not a continuing authorization grant. Deletion/block events invalidate cached cards and image access. Cursor expiry should restart a defined session without exposing hidden encounter records.

For Likes You, compute the eligible set before counting or applying entitlement presentation. Before release, send no person's identity, portrait, original URL or per-person timer. After release, a free locked preview can receive only an appropriately transformed asset and opaque preview token. CSS/Flutter blur over a downloaded original is not access control. Premium resolves the same eligible set through server-authorized originals. Already downloaded images cannot be remotely “unseen”; limit caching and access lifetimes instead of promising that capability.

## 6. Atomic permanent removal and race prevention

Use one canonical pair record with a uniqueness constraint. All pair-changing transactions—like, mutual match creation, disconnect, block and message acceptance—must serialize against that record, or use an equivalent database mechanism with proven guarantees.

An idempotent disconnect operation authenticates the actor, locks/checks the pair, writes its permanent tombstone, closes the match/thread, makes messages unavailable to both participants, increments the pair revision and commits an invalidation event atomically. It must also work if no active thread remains. Retries with the same operation ID return the same outcome. Ordinary unblock never deletes this tombstone.

Blocking an active connection creates both a directed block and the permanent tombstone in the same transaction. Blocking an unmatched profile creates only the block. Report-only adds a report without changing the relationship; report-plus-block has explicit combined semantics.

A racing second like or message checks the tombstone within its own serialized transaction before committing. A client-side preflight or an eventually updated feed cache is insufficient. Use a transactional event/outbox mechanism; publishers and consumers respect pair revisions, and clients discard stale queued events after closure. Messages accepted before closure and bytes already delivered cannot be retracted from a recipient's memory. Decide server erasure/evidence retention separately while enforcing immediate application-level unavailability.

## 7. Proposed transport surface

The following REST/realtime names are illustrative adapter contracts, not existing endpoints. Derive account identity from authentication, never a caller-supplied `actorId`. Use opaque IDs, schema validation, operation IDs, explicit failure codes and version checks where edits can conflict.

| Operation | Proposed contract |
| --- | --- |
| Authentication | `POST /auth/phone/challenges`; `POST /auth/phone/verifications`; session refresh/revocation |
| Account/setup | `GET /me`; versioned `PATCH /me/profile`, `/me/preferences`; staged photo upload/finalize/delete |
| Introduction | `GET /me/intro`; idempotent `POST /me/intro/completion` with content version |
| Observations | `POST /location-samples:batch` returns accepted/rejected sample IDs; response reveals no nearby identities |
| Discovery | `POST /discovery-sessions`; `GET /discovery-sessions/{id}/cards?cursor=…`; eligible detail/media authorization |
| Likes/passes | Idempotent candidate-token like/pass commands and an eligible Rewind command; invalidated tokens fail closed |
| Chat | `GET /threads`; cursor-based message history; `POST /threads/{id}/messages` with client operation ID |
| Safety | `POST /pairs/{id}/disconnect`; directed block/unblock commands; `POST /reports`; own safety snapshot with revision |
| Premium | `GET /me/entitlements`; server-side store verification/notifications behind a purchase adapter |
| Realtime | Authenticated event stream with sequence, resource revision, event ID and reconnect cursor |

Return distinct outcomes for expired authentication, rate limiting, stale versions, missing setup, unavailable profiles, closed pairs and retryable transport failures. Avoid exposing whether an inaccessible account exists. Reconnect fetches a current authorized snapshot before replaying pending operations. Push notifications identify a refresh target and are not permission to display sensitive cached content.

## 8. Remaining implementation decisions and proof

Before real location collection, choose retention windows for raw samples, accepted encounters, expired feeds, media, message data, reports and tombstones. Define access roles, deletion behavior and how tombstones survive ordinary logout/device changes. “Never match again” is enforceable for the identified account pair; preventing evasion through newly created accounts is a separate abuse/identity decision. Do not claim the browser prototype solves it.

Store intro completion on the account and cache it with that account key. Visible-time playback is an onboarding UX requirement, not a security or age-assurance proof. Optional Profile replay cannot overwrite completion or manipulate dating data.

Required backend proof includes UTC boundary tests, unreliable/asynchronous sample cases, stable multi-page ordering, no unrevealed media access, no entitlement bypass, two-account authorization tests, disconnect/like/message races, duplicate retries, out-of-order events, storage failures and account switching. Native proof adds physical-device location/lifecycle measurements, accessibility and screenshot comparisons. Preserve the archived JavaScript checks as behavioral references; they do not validate a native app or a deployed service.
