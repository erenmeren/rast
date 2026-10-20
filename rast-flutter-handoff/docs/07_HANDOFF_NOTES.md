# Handoff notes and provenance

## Source identity

- Product: rast.
- Export date: 2026-10-20.
- Saved design version: 6.
- Source commit: `de646b9263e4c6d31dea0c0aa76d946da775ab88`.
- Hosted reference: https://rast-mobile-design.reynolds-9923.chatgpt.site .
- The source checkout was clean and matched the newest saved version when this export began.
- No live Site source, sharing policy or deployment was changed by this export.

The `prototype/` directory copies the source's `dist/`, `checks/`, `README.md` and `package.json`. Git history, hosting identity/configuration, credentials and runtime files are intentionally outside this portable handoff. The original prototype README describes its hosted source context; `START_HERE.md` contains the relevant local commands for this ZIP.

## Design authority

The user selected an English, modern dating-app style inspired by current mainstream apps, with a distinct restrained identity, large photographs and normal sans-serif type. Preserve the latest source's typography and cascade:

`assets/fonts/jakarta.css → style.css → v2.css → how-it-works.css → dark-mode.css`.

The older DM Sans and Instrument Serif files remain in the source snapshot for fidelity. They are not instructions to reintroduce rejected italic or serif styling.

The gallery, fake phone frame, sample reset, sample upload shortcuts and hard-coded stock-profile state are preview aids. Native navigation has only Discover, Likes You, Chats and Profile.

## Assets

The original photographs, web fonts, their credits and licenses are under `prototype/dist/assets/`. Preserve `credits.json`, `fonts/jakarta-sources.json` and the applicable OFL notices when moving assets. The photographs are fictional design placeholders; the pictured people are not rast users. Demo gender, age and preference labels do not describe the real people pictured.

The native handoff additionally contains:

- `design/flutter-assets/fonts/PlusJakartaSans-Variable.ttf`: normal-style official Google Fonts binary, renamed at the file level only; font content is unchanged.
- `design/flutter-assets/fonts/OFL.txt`: matching license from that source.
- `design/flutter-assets/fonts/source.json`: source URLs, Git blob hashes, SHA-256 values, byte sizes and retrieval date.
- `design/icons/*.svg`: 36 separate vectors extracted directly from the prototype's `paths` object. They preserve the original viewBox and stroke settings.

The TTF's metadata was read successfully: family Plus Jakarta Sans, Regular, variable weight axis 200–800 with default 400. The product uses normal weights 400–800. This verifies file structure, not rendering parity in a compiled Flutter app.

The custom-font guidance uses the official Flutter documentation: https://docs.flutter.dev/cookbook/design/fonts and https://api.flutter.dev/flutter/painting/TextStyle-class.html . Use TTF/OTF for a portable native asset workflow; do not just rename a WOFF2 extension to TTF.

Source provenance for the added font: https://github.com/google/fonts/tree/main/ofl/plusjakartasans . The included binary and its stored hashes remain usable even if an upstream branch later changes.

## Existing behavior versus production work

| Existing web reference | Required future implementation |
| --- | --- |
| Fixed sample OTP 246810 | Real phone verification, session lifecycle and abuse limits |
| Seeded encounters and accurate=true | Actual permissioned location evidence, freshness/accuracy policy and server crossing computation |
| Local delay and age checks | Authoritative server eligibility and UTC reveal logic |
| CSS blur over known demo portraits | Access-controlled protected previews; unauthorized originals never delivered |
| In-memory chat, fake matches | Authenticated two-party matching, realtime delivery and durable conversation state |
| Browser-local disconnected IDs | Permanent pair enforcement across server transactions, devices and reconnects |
| Local report metadata | Moderation intake, retry states, access restrictions and chosen retention workflow |
| Simulated subscription buttons | Verified store purchases, restore, revocation and server entitlements |
| Browser-local introduction flag | Account-scoped onboarding completion and lifecycle-aware native playback |

## Production decisions to record

Read the product and architecture documents for context. These decisions are not silently settled by the prototype:

1. Backend, SMS/phone verification, object storage, push, purchase and moderation providers.
2. Platform support targets and the supported background-location strategy after real-device testing.
3. Location accuracy, timestamp freshness/coincidence, encounter deduplication and candidate expiry.
4. Whether a delay change affects already pending encounters and how to avoid shortening an already promised wait.
5. Production age representation/age assurance; the prototype's 130 upper input bound is not a newly requested age policy.
6. Matching semantics for a self-described identity beyond the explicit Everyone preference, without inferring category from text.
7. Treatment of blocked and permanently removed pairs after deletion/re-registration, including the identity and data-retention scope.
8. Production photo policy and moderation, subscription product/pricing details, and report handling.

The next AI should keep the design work moving with explicit mock settings while isolating these choices. Implementing mocks does not authorize provisioning paid services or publishing an application.

## Validation meaning

The exported web reference is checked with its existing Node tests, and the archive is checked for intact files, valid local references, XML/JSON structure and checksum consistency. Native mobile compilation, real-device GPS behavior and visual rendering of the Flutter port cannot be tested because no Flutter port is part of this deliverable.

See `handoff-manifest.json` for the actual commands and counts. Checksum validation proves archive integrity against this export's recorded files; it is not a third-party security audit or code-signing guarantee.

