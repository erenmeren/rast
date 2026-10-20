# Instruction for the implementation AI

You are implementing **rast**, a native English-language dating application in **Flutter and Dart**, targeting Android and iOS.

This archive contains an agreed interactive design, product rules, original assets and an implementation plan. Treat it as the source of truth for this handoff. Inspect it before proposing a different visual direction.

## Read first

1. `START_HERE.md`
2. `docs/01_PRODUCT_SPEC.md`
3. `docs/02_SCREEN_MAP.md`
4. `docs/03_FLUTTER_IMPLEMENTATION_PLAN.md`
5. `docs/04_ARCHITECTURE_AND_DATA.md`
6. `docs/05_ACCEPTANCE_CRITERIA.md`
7. `docs/06_DESIGN_SYSTEM.md`, `design/tokens.json`
8. `docs/07_HANDOFF_NOTES.md`

Inspect `prototype/dist/index.html` and the actual CSS cascade, `app.js`, `rules.js`, `how-it-works.js` and existing checks. Run the local prototype when your environment supports it. Read the code when browser automation is unavailable, and state that visual parity remains unverified.

## Required implementation direction

Build a new native Flutter project. Use reusable Flutter widgets, proper navigation, typed models, state controllers and repository interfaces. Preserve the Plus Jakarta Sans typography, photo-first layout, coral/charcoal visual identity, four-tab navigation, light/dark themes and animation story. The desktop phone frame, gallery and demo controls are development aids, not mobile app screens.

Use the proposed architecture as a starting point. Riverpod and go_router are recommendations, not additional product requirements. Select compatible stable Flutter/Dart/package versions in the implementation environment, record them and lock dependencies. Do not invent package versions or native capabilities.

Build working mock repositories first so every screen and rule can be reviewed without service credentials. Keep mock and production implementations explicit. Real SMS, background location, purchases, moderation and messaging must use their service adapters before being described as live.

## Non-negotiable product rules

- English interface; no italic type or unnecessary profile questionnaire.
- Phone plus code authentication. Explicit age and gender. Adults only, 99+ display. Four photos required. No required name, job, religion or biography.
- Inclusive identities and dating interests; one age-range control with two handles.
- Discover is the only encounter swipe deck. Main navigation: Discover, Likes You, Chats, Profile.
- A crossing requires at most 20 metres between people, mutual eligibility and sufficiently trustworthy contemporaneous location evidence. Two 20 m circles overlapping is not an alternative 40 m rule.
- Location targets: 15, 30, 45, 60, 75, 90, 105, 120 seconds. Default 30 seconds.
- Reveal choices: immediate, 1, 2, 4, 6, 12, 18, 24 hours. Default 2 hours. Both users wait for the longer preference.
- Randomized encounter order, stable during a viewing session. Never use chronological encounter order as the user-facing feed.
- No exact crossing time, precise location, map pin or identifiable unrevealed profile. Premium does not bypass any eligibility or privacy gate.
- Eligible incoming likes have a blurred free preview. Premium reveals only authorized, already-eligible likes. Mutual matching and chat remain free.
- Removing a connection permanently closes that account pair; neither user can match or message the other again. Removing a block must not resurrect a removed connection.
- Reporting can be separate from blocking; removed connections remain reportable.
- A one-time mandatory explanation follows completed setup. Pause is allowed; skipping/continuing before completion is not. Reduced motion remains accessible. Optional replay is under Profile, not a fifth navigation tab.
- System, Light and Dark appearances must cover all screens, sheets and animation states.

## Work sequence

Begin with a concise source audit and phase tracker. Identify genuine production decisions from the docs, and use clearly marked provisional settings for isolated mocks. Start the real-device location feasibility work early: do not promise that a Dart timer can deliver guaranteed background updates on every phone.

Implement the first native visual milestone, then onboarding and the once-only introduction, discovery and likes, matching/chat/safety, real service integration and release validation according to the plan. Make each milestone runnable before progressing. Inspect keyboard handling, small screens, safe areas and large text, not just static screenshots.

Keep server-authoritative rules on the server. Enforce pair removal atomically and idempotently across concurrent likes, message sends, devices and reconnects. Do not ship an unblurred image URL to an unauthorized client and rely on a UI blur to protect it. Never reuse the hard-coded demo OTP or localStorage-style safety as production enforcement.

## Expected deliverables in the new project

- Runnable Flutter source with documented commands and environment placeholders.
- Mock mode that reproduces the agreed screen flows with fictional data.
- Clear repository/API contracts and the current backend integration status.
- Focused Dart domain tests, widget tests and critical two-user integration scenarios from the acceptance document.
- Real-device location/battery findings with measured results and unresolved constraints.
- A concise completion report for each phase: what runs, what was tested, what is simulated and what still needs configuration.

Proceed autonomously with reversible implementation decisions. Ask only when a missing product decision, real account access or a consequential external action blocks the next step. Never silently broaden the scope or claim a store-ready application before the required integrations and verification exist.

