# rast — design and Flutter/Dart handoff

Prepared on 20 October 2026. This package exports the current rast design and a plan for building its native mobile application in Flutter and Dart.

## What is delivered

| Path | Purpose |
| --- | --- |
| [BASLANGIC_TR.md](BASLANGIC_TR.md) | Turkish quick-start and handoff instructions for the owner |
| [AI_HANDOFF_PROMPT.md](AI_HANDOFF_PROMPT.md) | Ready-to-use instruction for the next implementation AI |
| [prototype/](prototype/) | Complete working HTML/CSS/JavaScript prototype, local photos/fonts and existing checks |
| [docs/01_PRODUCT_SPEC.md](docs/01_PRODUCT_SPEC.md) | Agreed product rules, prototype behavior and unresolved production choices |
| [docs/02_SCREEN_MAP.md](docs/02_SCREEN_MAP.md) | Screens, sheets, navigation, states and proposed Flutter widgets |
| [docs/03_FLUTTER_IMPLEMENTATION_PLAN.md](docs/03_FLUTTER_IMPLEMENTATION_PLAN.md) | Ordered development phases, deliverables, dependencies and completion gates |
| [docs/04_ARCHITECTURE_AND_DATA.md](docs/04_ARCHITECTURE_AND_DATA.md) | Suggested Flutter structure and server/API/data responsibilities |
| [docs/05_ACCEPTANCE_CRITERIA.md](docs/05_ACCEPTANCE_CRITERIA.md) | Concrete verification cases for the future implementation |
| [docs/06_DESIGN_SYSTEM.md](docs/06_DESIGN_SYSTEM.md) | Current light/dark visual system and native translation guidance |
| [docs/07_HANDOFF_NOTES.md](docs/07_HANDOFF_NOTES.md) | Source provenance, limits, asset notes and implementation boundaries |
| [design/tokens.json](design/tokens.json) | Machine-readable design tokens with their provenance |
| [design/screen-inventory.json](design/screen-inventory.json) | The 16 main prototype screen definitions, exported from source |
| [design/icons/](design/icons/) | 36 individual SVG icons extracted from the prototype |
| [design/flutter-assets/fonts/](design/flutter-assets/fonts/) | Official normal-style Plus Jakarta Sans variable TTF and OFL license |
| [tools/preview.py](tools/preview.py) | Standard-library Python launcher for the local web design |
| [tools/verify_package.py](tools/verify_package.py) | Package checksum verification |
| [handoff-manifest.json](handoff-manifest.json) | Export identity, source version and validation record |

## What this is

The working application in this archive is the **web design reference**. The Flutter/Dart implementation is specified and planned; it has not been built in this export. There is no APK, IPA, signed mobile release or production backend here. Start the native implementation in a new Flutter project and use this package as its reference. Do not wrap the web preview in a WebView and call the port complete.

The application interface and technical handoff documents are in English. The short owner guide is in Turkish. The visual direction, screens and agreed rules have already been chosen; the next AI should preserve them.

The exported source matches saved design version 6, commit `de646b9263e4c6d31dea0c0aa76d946da775ab88`.

Optional hosted reference: https://rast-mobile-design.reynolds-9923.chatgpt.site — this can require the owner's access. The local preview is independent of that access.

## Preview the design locally

Extract the ZIP before running these commands. Python 3 is sufficient; no npm install or build is required.

From the extracted `rast-flutter-handoff` directory:

```sh
python3 tools/preview.py
```

On Windows:

```powershell
py tools/preview.py
```

The launcher serves only the bundled preview on `http://127.0.0.1:8020`, opens a browser when possible, and stops with Ctrl+C. If the port is occupied, run `python3 tools/preview.py --port 8021`. To leave browser opening to you, add `--no-browser`.

An equivalent standard-library command is:

```sh
python3 -m http.server 8020 --bind 127.0.0.1 --directory prototype/dist
```

Opening `index.html` directly with a `file:` URL is not the supported route because the prototype uses JavaScript modules.

The desktop preview includes the interactive phone and screen gallery. The gallery is a design aid, not part of the native mobile navigation. Try Profile → Appearance, Location & visibility, How it works and Safety & account. Chat options contain Remove connection, Report profile and Block profile. The sample OTP is `246810`. Sample data and purchase/report actions are explicitly simulated.

## Give the archive to another AI

1. Upload the whole ZIP, or extract it into that AI's accessible workspace.
2. Ask the AI to read `START_HERE.md`, then `AI_HANDOFF_PROMPT.md` and the numbered documents.
3. Paste the contents of `AI_HANDOFF_PROMPT.md` as the initial instruction if the AI needs a chat prompt.
4. Ask it to keep a phase tracker and decision log in its new Flutter repository.
5. Require a running native mock-data version for visual review, then connect real services through the proposed repository interfaces.

The full source and assets matter: a screenshot alone would lose the animation timing, safety behavior, dark-mode states and filter rules.

## Verify the export

```sh
python3 tools/verify_package.py
```

Optional Node checks for the web reference, from the package root:

```sh
node --check prototype/dist/app.js
node --test prototype/checks/rules.test.mjs
node prototype/checks/app-smoke.test.mjs
```

The checks exercise JavaScript logic and a simulated DOM. They are not Flutter compilation, rendered CSS comparison, GPS validation or real-device mobile tests. The exact export validation is recorded in the manifest.

## Decision hierarchy

1. The owner's current explicit instructions take priority.
2. Agreed requirements in `01_PRODUCT_SPEC.md` define product behavior.
3. The source and `06_DESIGN_SYSTEM.md` define the existing visual reference.
4. Architecture, packages, endpoints and production policy suggestions are proposals.
5. Demo shortcuts must not silently become production behavior.

Do not let legacy unused serif/italic assets override the current Plus Jakarta Sans design. Do not let the browser's fixed sample profiles, local storage or hard-coded OTP define production identity or safety.

