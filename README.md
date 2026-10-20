# rast

**Good things happen nearby.**

rast is a native, English-language dating app for iOS and Android, built with Flutter and Dart. Instead of endless browsing, rast shows you people whose paths actually crossed yours in real life: within about 20 metres, after a privacy delay, and only when you fit each other's preferences.

> Status: **in development**. The first milestone is a fully navigable native app running on mock data. Real SMS verification, backend, location processing, chat delivery and purchases are added afterwards behind the same repository interfaces.

## Product rules (agreed, non-negotiable)

- English interface. Plus Jakarta Sans, no italics. Photo-first layout, coral actions, light and dark themes.
- Sign up with a phone number and a code. Then: your age, your gender, who you want to meet, four photos. No name, job, religion or biography.
- Adults only. Ages 99 and above display as **99+**.
- Identity (Woman, Man, Non-binary, Self-describe) and interests (Everyone, Women, Men, Non-binary people) are separate. One age range, two handles, 18 to 99+.
- Four tabs: **Discover · Likes You · Chats · Profile**. "How it works" lives inside Profile, never as a fifth tab.
- A crossing means **at most 20 metres between two people**, mutual eligibility and trustworthy, contemporaneous location evidence.
- Location update target: 15 to 120 seconds (default 30). Reveal delay: immediate to 24 hours (default 2 hours). **The longer delay of the two people always wins.** Premium never shortens it.
- Discover order is randomised and stable during a session. Never a timeline.
- No exact crossing time, location, map pin or identifiable unrevealed profile is ever shown.
- Incoming likes are blurred for free members. Premium reveals only already-eligible likes. Matching and chat stay free.
- Removing a connection is permanent for that pair. Unblocking never resurrects a removed connection. Reporting works with or without blocking.
- A one-time introduction plays after setup. Pausing is allowed; skipping is not.

## Repository layout

```
rast/
├── README.md
├── rast-flutter-handoff/     # Design and product handoff: the source of truth
│   ├── docs/                 # Product spec, screen map, plan, architecture, acceptance, design system
│   ├── design/               # tokens.json, screen inventory, 36 SVG icons, Plus Jakarta Sans TTF
│   └── prototype/            # Working HTML/JS reference prototype (run: python3 tools/preview.py)
├── docs/superpowers/         # Design and implementation plans for this repo
├── lib/                      # Flutter application (feature-based)
│   ├── app/                  # Bootstrap, router, dependency composition
│   ├── core/                 # Theme, shared widgets, platform bridges
│   └── features/             # auth, onboarding, intro, discovery, likes, chat, safety, profile, premium
├── test/                     # Domain, widget and flow tests
├── android/ ios/             # Platform projects
└── assets/                   # Fonts, icons, placeholder photos
```

## Architecture

- **Flutter stable** with Dart. Versions are recorded in `pubspec.lock` and `.fvmrc`/`flutter --version` output in the docs.
- **Riverpod** for state and dependency injection. **go_router** for navigation with guards for session, setup completion and the required introduction.
- **Repository interfaces** (`AuthRepository`, `ProfileRepository`, `DiscoveryRepository`, `MatchRepository`, `ChatRepository`, `SafetyRepository`, `IntroRepository`, `EntitlementRepository`, `LocationRepository`) with explicit **mock** implementations today and **production** adapters later. Screens never know which one they are talking to.
- Pure domain rules (eligibility, delay, age range, shuffle) live in plain Dart and are unit-tested against the prototype's fixtures.

## Getting started

```sh
flutter --version          # stable channel
flutter pub get
flutter run                # mock mode is the default
flutter test
flutter analyze
```

Mock mode uses fictional profiles and stock placeholder photos. The sample verification code is `246810`. No SMS is sent, no location is collected, no payment is taken.

## Roadmap

| Phase | Scope | Status |
| --- | --- | --- |
| 1 | Native foundation: theme, typography, components, four-tab shell | planned |
| 2 | Onboarding (phone → code → about you → preferences → photos → location) and the one-time introduction | planned |
| 3 | Discover deck, Likes You, person detail, eligibility rules | planned |
| 4 | Match, Chats, conversation, remove/block/report, Safety & account | planned |
| 5 | Real backend, SMS verification, location evidence, realtime chat | later |
| 6 | Store purchases, entitlements, release validation | later |

## Reference

Everything about the product, screens, copy and visual system is in `rast-flutter-handoff/`. Start with `rast-flutter-handoff/START_HERE.md`.

## License

Private. The bundled Plus Jakarta Sans font is licensed under the SIL Open Font License (see `rast-flutter-handoff/design/flutter-assets/fonts/OFL.txt`). Placeholder photographs are credited in `rast-flutter-handoff/prototype/dist/assets/credits.json`; the people pictured are not rast users.
