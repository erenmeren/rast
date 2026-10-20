# rast — product specification for the Flutter handoff

## Scope and source of truth

Reference: saved version 6, commit `de646b9263e4c6d31dea0c0aa76d946da775ab88`. Rebuild the English mobile experience in Flutter/Dart. The website, desktop frame, gallery and demo helpers are references, not a native app or backend.

ZIP-root sources: [prototype/dist/app.js](../prototype/dist/app.js) (screens/actions), [prototype/dist/rules.js](../prototype/dist/rules.js) (eligibility), [prototype/dist/how-it-works.js](../prototype/dist/how-it-works.js) (introduction), [prototype/README.md](../prototype/README.md) (limits). See [02_SCREEN_MAP.md](02_SCREEN_MAP.md) for routes and copy.

## Agreed product requirements

### Fast signup, adult membership and inclusive preferences

Verify a phone number, then ask for own age, gender, dating preferences and four photos. No mandatory name, occupation, religion, biography or email. Signup/login share phone entry; the number is private.

Under-18s cannot use the service. Public ages and the upper preference endpoint use **99+** for ages 99 and older; this is a display convention, not a maximum membership age. The prototype input guard is separate.

Identity and interests are separate. Current identities: **Woman**, **Man**, **Non-binary**, **Self-describe**; multi-select interests: **Everyone**, **Women**, **Men**, **Non-binary people**. Signup has no selected gender. Self-describe requires text; **Show my gender on my profile** is optional. Everyone includes all identities.

Use **one age-range track with two handles**, named Minimum age and Maximum age, spanning 18–99+. Preference edits remain drafts until **Save preferences**. Four photos are mandatory; the first is primary. Removing one pauses discovery until replaced. Existing chats remain accessible.

### Encounters, privacy and ordering

An encounter requires **at most 20 metres between people's centres**. Two 20-metre-radius circles touching at 40 metres do not qualify. The brand mark does not define distance.

Both people must be adults, available and mutually compatible in age/gender preferences, with location access, complete photos and usable readings. Neither blocking nor permanent disconnection may exist. Apply these checks before Discover or Likes You exposes anyone.

| Setting | Values | Default |
|---|---|---|
| Location update target | 15, 30, 45, 60, 75, 90, 105, 120 seconds | 30 seconds |
| Profile reveal delay | Immediate, 1, 2, 4, 6, 12, 18, 24 hours | 2 hours |

Background collection is intended, subject to native permissions and operating-system limits. Intervals are targets, not guaranteed schedules.

Apply `max(personA.delay, personB.delay)` from the qualifying encounter. Immediate and Premium cannot override the other person's wait. Unreleased people must not appear through blurred photos, identifiable previews, exact times, personal countdowns or maps. UI says approximately 20 metres to reflect reading uncertainty; exact whereabouts stay private.

Randomize eligible encounters independently of timestamps; preserve relative order through photo browsing, rerenders, tabs and filter changes. Like/pass targets the displayed person. Rewind restores only a still-available pass. There is no Encounters tab.

### Matching, subscription and safety

Tabs: **Discover · Likes You · Chats · Profile**. Photo-edge taps browse albums; horizontal swipes/buttons like or pass. Swiping must suppress photo taps. Mutual likes create one connection and enable chat. Discovery, matching and chat remain free.

Likes You blurs eligible incoming likes for free members; subscription reveals the same eligible profiles. No entitlement bypasses eligibility, privacy or exclusion checks. Ending subscription retains established chats.

| Action | Required result |
|---|---|
| Remove connection | Confirm; delete match/chat; exclude the pair from Discover and Likes You; prevent future matching or thread creation. No undo. |
| Block an existing connection | Block and permanently remove the connection. Later Unblock cannot restore it or permit rematching. |
| Block without an existing connection | Hide the profile while blocked; reversible through Blocked profiles. |
| Report without blocking | Record the concern; leave the connection intact. |
| Report with blocking | Apply the relevant block rule above; explain permanent removal when already connected. |

Keep Removed connections under Safety & account with Report, no restore. Reasons: **May be under 18**, **Fake profile or someone else’s photos**, **Harassment or inappropriate behaviour**, **Scam or spam**, **Another reason**. Details are optional.

### Introduction and appearance

Both location choices trigger the introduction once after completed signup. Allow pause/resume, with no skip, seek, replay or in-app exit that bypasses completion. Operating-system app exit remains possible; an unfinished account stays gated on relaunch. **Watch to continue** becomes **Start exploring** after visible playback completes. **Profile → How it works** later allows optional replay; never add a fifth tab.

Retain Plus Jakarta Sans without italics, coral actions, large photos and restrained illustration. Persist **System/Light/Dark**: System follows device changes; explicit choices remain fixed. Reference `prototype/dist/v2.css`, `prototype/dist/dark-mode.css`, `prototype/dist/how-it-works.css` and included asset provenance. Native assets: `design/flutter-assets/fonts/` and `design/icons/`.

## Current prototype choices and limits

- **Authentication and age:** OTP `246810` is fixed; no SMS or authentication occurs. The age field accepts integer 18–130; 130 is a plausibility guard, not an agreed maximum-user-age policy. Date-of-birth helpers exist in `rules.js`, but signup currently asks numeric age. Self-reported age and a phone code do not establish adulthood.
- **Fixtures:** Six sample IDs, preset reciprocal interests, seeded messages and synthetic encounter ages drive eligibility. The app initializes as a usable demo. Photo albums reuse stock portraits, crops and a city photo; these are not four verified personal photos. Upload acceptance is JPEG/PNG/WebP up to 10 MB. No location, live messages, photo moderation or real people are connected.
- **Ordering and payment:** Fisher–Yates shuffles IDs on app load or Reset preview, not every render. “Get rast Plus” changes an in-memory flag. Monthly/annual prices are illustrative; Restore purchases is a demo response. CSS blur hides presentation only: original sample image URLs remain client-accessible. Neither blur nor a client Premium flag is production authorization.
- **Persistence:** Profile data, phone, photos, messages and Premium reset on reload. `rast-design-settings` stores timing, notifications and theme; `rast-intro-v1` stores pending/complete; `rast-safety-v1` stores blocked/disconnected sample IDs and report reasons. Optional report details are not saved. Safety survives logout and another setup in the same browser. Reset preview and Delete demo account clear demo safety explicitly.
- **Multiple tabs and write failures:** Safety events read the latest stored record; actions apply targeted operations to that snapshot. Failed writes leave pending operations in memory to replay on later refresh/save, preserving session exclusions. This is browser-local behavior, not cross-device synchronization or an atomic production transaction.
- **Introduction:** Playback lasts 27.4 seconds. Pending reload restarts it; completed reload does not. Hidden/background time is excluded; the visible-scene threshold is 40% when supported. Credited frame deltas cap at 100 ms to prevent stalls skipping chapters. Reduced motion uses timed static chapters for the required viewing and Next step for optional replay. All map-like movement is illustrative.

## Production decisions still open

Resolve these explicitly in the implementation plan rather than silently inheriting demo shortcuts:

1. Account authentication/recovery, adult-assurance approach, DOB versus maintained numeric age, and any real upper-age validation policy.
2. Inclusive identity taxonomy and matching rules for self-described identities. Currently these match Everyone but have no mapping into the three specific interest categories. Do not guess that mapping.
3. Native permission sequence, background operation, battery behavior, accuracy/freshness thresholds, stale or uncertain readings and encounter deduplication. Repeated crossings, encounter expiry and whether later delay edits affect an already-pending encounter are unresolved.
4. Server-owned pair exclusion, idempotent likes/matches, message authorization, removal on both devices, and behavior during concurrent actions or failed requests. Demo reset exceptions must not become production rematch controls.
5. Report handling, evidence retention, photo validation/storage, entitlement verification and final subscription plans. Never tell members a report was submitted until the real service accepts it.
6. Account-scoped introduction completion, location-data retention, feed refresh/shuffle lifecycle and offline policies. Implement loading/error states identified in the screen map; the synchronous prototype does not provide them.
