# rast — mobile design prototype

An English mobile-first dating application design with 16 main screens, interactive onboarding, a single photo-led Discover screen, Likes You, an animated How it works story, a subscription preview, matching, chat, profile, location settings, and safety sheets. It supports System, Light and Dark appearance. Desktop includes an interactive device view and a full screen gallery.

## Scope

This is a browser-local design prototype. It does not send SMS, collect geolocation, connect users, moderate reports, charge payments, or provide a real account backend. The demo OTP is `246810`. Profile data is fictional; stock photos do not represent actual users. The four-photo profile albums use sample crops and a city image to demonstrate navigation. Image provenance is in `dist/assets/credits.json`; the current font license and source are under `dist/assets/fonts/`.

Phone numbers, ages, gender selections, photos selected by the visitor, chat messages and the Premium demo state stay in memory. Interval, delay, notification and appearance preferences, the non-personal introduction status, and safety decisions about fictional sample profile IDs are persisted in localStorage. A saved report contains only a sample profile ID and one of the predefined reasons; optional written details are not saved. Refreshing resets the remaining demo state. Uploaded images use temporary local blob URLs.

## Product decisions

- An encounter uses a distance of 20 metres or less between two people. Two separate circles each with a 20 m radius would overlap at 40 m; that is not the chosen rule.
- Both people must be adults, visible, and satisfy each other's age and gender preferences.
- Reveal delay is the longer of the two preferences: immediate, 1, 2, 4, 6, 12, 18 or 24 hours. Two hours is the default. Choosing immediate does not override the other person's delay.
- Unrevealed people are not exposed through a blurred portrait, exact time, or a personal countdown.
- Onboarding explicitly requires a whole-number age and a gender selection. No default gender is selected when signup begins. Under-18s cannot continue; ages above 130 are rejected as invalid input. SMS control and self-reported age are not a production age-assurance system.
- Age filters begin at 18; the maximum value 99 means 99 and older.
- One shared age-range track has two independently accessible handles. Filter-sheet edits apply only after saving.
- Four photos are required before discovery. Removing a photo pauses eligibility until all four are present.
- Gender identity and interest preferences are separate, including self-description and multi-select interests.
- Discover is the only photo deck for eligible real-life encounters. The four main tabs are Discover, Likes You, Chats and Profile. Tap photo edges to browse an album; swipe horizontally or use the buttons to like/pass. Rewind restores the last available pass.
- The deck is shuffled independently of encounter timestamps once on app load or Reset preview. Photo changes, rerenders, tab changes and filter updates retain that relative order. Eligibility and privacy delays are checked before a shuffled profile can appear.
- Profile contains a How it works link for optional replays. Finishing signup opens the short introduction once, whether location is enabled or deferred. The first viewing has pause/resume and a disabled continue button until all five scenes finish; it has no skip or chapter seeking. Later app visits do not force another viewing.
- Likes You shows a blurred preview only for eligible incoming likes after the mutual privacy delay. The demo Premium upgrade reveals exactly the same set. A subscription does not bypass distance, age, preference, visibility, blocking, permanent connection removal or privacy-delay gates.
- Monthly and annual subscription prices are examples only. The upgrade and restore controls simulate a purchase flow; they do not communicate with a payment service.
- Free members can continue discovering, matching and chatting without a subscription. Ending the Premium preview leaves existing matches and chats intact.
- Location update targets are 15, 30, 45, 60, 75, 90, 105 or 120 seconds, with a 30-second default. These are requested intervals, not mobile OS scheduling guarantees. Real background location and accuracy require native-platform validation.
- Profile → Appearance offers System, Light and Dark. System follows live device appearance changes; an explicit Light or Dark selection stays fixed. The saved choice is applied in the document head to reduce a light flash on reload.

### Removing, blocking and reporting

The conversation menu offers Remove connection, Report profile and Block profile. Removing a connection requires confirmation and deletes its match and conversation, excludes both discovery and incoming likes, and prevents any new thread or match with that sample profile. Removed connections remain listed under Safety & account so they can still be reported, with no restore control.

Blocking an existing connection also permanently removes that connection. Unblocking that person does not restore a chat or allow a future match. Blocking a profile without a connection is reversible from the blocked list. Reporting allows a predefined reason and optional details, with an optional block action; reporting without blocking leaves the connection intact. The interface states that no actual moderation report is sent by this prototype.

The `rast-safety-v1` record stores blocked IDs, permanently disconnected IDs and report reasons. Loading the app removes unavailable seeded threads and stale profile references. Safety decisions survive reload, sign-out and another setup attempt in the same browser; Reset preview and deleting the demo account explicitly clear them. Open tabs process storage changes by reading the latest saved record, and safety actions apply their intended change to that latest snapshot. If storage writes fail, pending changes are retained and reapplied during the current session until saving succeeds. Stale cards, message forms, match actions and Rewind cannot restore an unavailable person.

This is browser-local prototype behavior. A production service must enforce removal against the authenticated pair of accounts on the server, including both people's discovery feeds, likes, existing conversations and future match creation. Cleared browser storage, other browsers or devices, and genuinely concurrent server operations are outside this demo's persistence guarantees.

## Visual system

- Paper: `#ffffff`
- Coral accent: `#fa634f`; action text uses a deeper coral background for contrast.
- Ink: `#202124`
- Dark surfaces: `#18191d` and `#24252b`; primary text `#f5f3f1`; coral accent `#ff907f`.
- All typography: Plus Jakarta Sans, normal style, weights 400–800. No italic typography. Fonts and assets are self-hosted.
- Larger photographs, bold concise headings, legible secondary text and distinct message bubbles.
- Intersecting circles form the brand mark and recurring graphic.
- `dist/dark-mode.css` covers app screens, sheets, navigation, forms, chat, the animated explanation and the desktop gallery. It changes interface surfaces and illustration colors while preserving photographs.
- Inspiration: official Tinder and Bumble app-store screenshots, plus their official Likes documentation: https://www.help.tinder.com/hc/en-us/articles/115005246123-Likes and https://support.bumble.com/hc/en-us/articles/28423161699485-Viewing-who-s-liked-you. No reference app artwork is included in this prototype.

## Files and checks

### Animated explanation

`Profile → How it works` opens a separate, replayable 27-second illustration, with Profile selected in the four-item bottom navigation. The direct URL fragment `#how-it-works` also opens it. It is structured as five chapters: walking within about 20 metres, reciprocal preferences, the longer privacy delay, the profile appearing in Discover, and two separate likes opening a conversation.

The first introduction opens after the location choice at the end of completed signup. Both Enable location and Not now use the same completion flow, after checking verification, adult age, gender, preferences and four photos. That first viewing has no bottom navigation or app exit controls. Pause remains available; chapter seeking and replay are unavailable until the introduction is finished and left. Only actual visible playback completes the introduction and enables Start exploring. The prototype's external screen shortcuts and gallery controls are inactive during this flow.

The `rast-intro-v1` localStorage key records only a pending or complete status. Reloading an unfinished introduction restarts it from the beginning and keeps the gate active. A completed introduction is not required again on reload, sign-in or another setup attempt in the same browser. Reset preview or deleting the demo account clears that flag so the flow can be tried again. Storage being unavailable means completion can only be remembered for the current session. Production would store completion on the authenticated account; this browser-local demo does not implement account-level enforcement across devices or cleared storage.

The illustration uses generic person symbols before the delay, an abstract street scene, and one 20-metre circle at four SVG units per metre. Crossing is computed from the two displayed centres, rather than two circles touching. It illustrates a 1-hour versus 2-hour preference, applies the 2-hour wait, and explicitly labels the clock as fast-forwarded. All sample photos appear visually only after the illustrated wait. These are fictional teaching scenes; they do not represent live location data or manipulate the demo account.

`dist/how-it-works.js` contains the component and its single requestAnimationFrame controller; `dist/how-it-works.css` contains scoped styles. Optional replays can pause, replay, or jump to chapters. Playback stops on navigation or hidden documents. Required playback also pauses when the scene is less than 40% visible, using IntersectionObserver when available, and caps each frame's credited time at 100 ms so foreground stalls cannot skip unseen chapters. The gallery uses a still frame and never completes onboarding. Reduced-motion users see static chapters: the first viewing advances those scenes on the same elapsed timer without moving people, while optional replays offer a Next step control. Motion preference changes never skip required watch time. Browser layout and native-device performance still need visual validation on a supported browser/device.

Buildless static app under `dist/`. The hosting manifest declares that directory.

```sh
node --check dist/app.js
node --test checks/rules.test.mjs
node checks/app-smoke.test.mjs
```

The smoke check executes the actual rendering and event handlers using a minimal DOM model in Node. It covers onboarding validation, one-track age filtering, the Discover swipe deck, photo taps and drag suppression, subscription preview, matching/chat, upload races, privacy gates, animation playback and all 16 main screens. Additional coverage verifies persisted appearance and device-theme changes, all interval and delay options through 24 hours, stable shuffled discovery, permanent removal, block/report choices, reload safety and stale-reference protection. These checks do not validate rendered CSS or native mobile behavior. A supported browser-control capability was unavailable in the authoring session, so browser visual QA was not performed.
