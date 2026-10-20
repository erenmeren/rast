# rast decision log

Product decisions come from the handoff. Entries here are engineering choices made while building, each reversible.

## 2026-10-20 — Toolchain

- Flutter 3.47.7 stable (framework abaf9c5237, engine deb287481e), Dart 3.13.5, installed at `~/development/flutter`.
- Android SDK at `~/Android/Sdk`: platforms android-35, android-36; build-tools 35.0.0, 36.0.0; command-line tools 11076708. OpenJDK 21.
- No Xcode on this machine: iOS is configured but not built here.

## Dependencies (resolved by `flutter pub add` on 2026-10-20)

| Package | Version | Why |
| --- | --- | --- |
| flutter_riverpod | 3.4.3 | app state + dependency injection, plain `Notifier` classes, no codegen |
| go_router | 18.1.1 | declarative routes, `StatefulShellRoute` for the four tabs, one redirect guard |
| shared_preferences | 2.5.6 | device-local appearance, timing, notifications, intro status, mock safety and session |
| image_picker | 1.2.4 | gallery picker for the four photos |
| flutter_svg | 2.3.0 | the 36 handoff icons, tinted with `ColorFilter` |

## Engineering choices

- The Flutter project lives at the repository root; the handoff stays in `rast-flutter-handoff/` untouched.
- Icons are tinted with a `srcIn` colour filter rather than editing the SVGs, so the handoff files stay byte-identical.
- The variable font is declared once as family `PlusJakartaSans`; weights are selected with `FontVariation('wght', n)` plus the nearest `FontWeight` bucket for engines that ignore variations.
- Mock OTP `246810` is only known to `MockAuthRepository`.
- Self-described identities match only the "Everyone" interest (prototype behaviour). Marked provisional: the handoff says not to guess a mapping.
- Prototype age guard 18–130 kept for the mock. Production age model is an open product decision.
