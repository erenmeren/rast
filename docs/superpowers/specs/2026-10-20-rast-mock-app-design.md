# rast — Milestone 1 design: navigable native app on mock data

Date: 2026-10-20. Owner decision: "Start directly. First a navigable version; database, SMS and the rest are added later."

## Intent

Build the complete rast mobile experience in Flutter so every screen, sheet, rule and animation from the design handoff can be walked through on a phone. All data is fictional and in-memory or device-local. Nothing talks to a network. Later milestones replace the mock repositories with real adapters without touching screens.

## Source of truth

`rast-flutter-handoff/` is the spec. In particular:

- `docs/01_PRODUCT_SPEC.md`: product rules (non-negotiable list repeated in README).
- `docs/02_SCREEN_MAP.md`: 16 screens, 3 extra routes, 15 sheets, exact copy, empty states.
- `docs/06_DESIGN_SYSTEM.md` and `design/tokens.json`: colours, type, dimensions, both themes.
- `prototype/dist/app.js`, `rules.js`, `how-it-works.js` and the CSS files: exact behaviour, copy and layout. When a doc and the prototype disagree, the prototype wins for copy and layout; the docs win for production rules.

## Goals

1. Every screen and sheet in the screen map exists natively, in light and dark, with the handoff copy.
2. Onboarding, the one-time introduction, Discover, Likes You, Premium preview, Match, Chats, Conversation, Profile, Location & visibility, Safety & account and all sheets are navigable end to end.
3. Domain rules are pure Dart, tested against the prototype fixtures.
4. Mock state is good enough to demonstrate: matching, chat, remove/block/report, premium preview, delay rules, pause visibility.
5. `flutter analyze` and `flutter test` are clean; an Android debug APK builds.

## Non-goals (this milestone)

Real SMS, backend, real location, push, purchases, moderation, photo upload to a server, iOS signing, store release, the Phase 0 real-device location study.

## Anti-goals

A WebView of the prototype. A fifth tab. Italic type. Any screen that shows an exact crossing time, distance or map. Premium bypassing any gate. A client blur standing in for access control being described as such (the mock blur is labelled a preview).

## Decisions made by the builder (reversible, recorded)

- Flutter 3.47.7 stable / Dart 3.13.5 (what was current on 2026-10-20). Versions locked in `pubspec.lock`.
- State: `flutter_riverpod` with plain `Notifier` classes, no code generation. Navigation: `go_router` with a `StatefulShellRoute` for the four tabs and a single redirect for session/setup/intro guards.
- Persistence: `shared_preferences` for appearance, timing, notifications, intro status, safety state and a mock session. Everything else in memory, like the prototype.
- Photos: `image_picker` from the gallery; paths kept in memory. In debug builds the photo step offers "Use sample photos" so a reviewer can get through setup fast. This is a dev aid like the prototype's "Fill this step".
- Icons: the 36 handoff SVGs rendered with `flutter_svg` and tinted with the current text colour.
- Font: the handoff's variable Plus Jakarta Sans TTF with `FontVariation('wght', …)` for weights 400 to 800.
- Mock OTP is `246810`, confined to `MockAuthRepository`.
- The app starts signed out at Welcome. After setup, the mock session persists so relaunch goes to Discover. Log out and Delete account return to Welcome.
- Open production decisions (age model, self-describe matching, location evidence, pending-encounter delay changes, retention) are NOT decided here. The mock uses the prototype's behaviour and marks it in code comments as provisional.

## Left to the builder

Widget decomposition, exact animation curves within the handoff's references, test organisation.
