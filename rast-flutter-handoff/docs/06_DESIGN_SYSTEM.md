# 06 · Design system and Flutter translation

## Preserve the approved direction

**rast is an English, photo-led dating app with confident Jakarta typography, coral actions and calm neutral surfaces.** Keep its restrained, contemporary character: generous portraits, strong hierarchy, compact outline icons and soft corners. Avoid cartoon decoration, italic headlines, ornamental fonts or a generic replacement theme.

The source of truth is the app inside the supplied prototype, not the desktop presentation around it. The phone frame, studio navigation, annotations, gallery and 33px preview bar are review tools; exclude them from the native product. Keep four bottom destinations, in order: **Discover · Likes You · Chats · Profile**. “How it works” belongs inside Profile and the one-time setup introduction, not a fifth tab. These are current source behaviours in [app.js](../prototype/dist/app.js).

## Read the cascade before porting values

[index.html](../prototype/dist/index.html) loads the style layers in this order:

1. `assets/fonts/jakarta.css`: the active font face.
2. `style.css`: original layout foundation and some inherited dimensions.
3. `v2.css`: the approved visual redesign, responsive rules and final readability overrides.
4. `how-it-works.css`: the dedicated animated introduction.
5. `dark-mode.css`: appearance controls, expanded timing grids and dark-theme overrides.

The old plum/lime palette and Instrument Serif/DM Sans references in `style.css` are legacy values overridden by the later layers. Do not reproduce them because they appear first. Within `v2.css`, the final `.phone-viewport` and `.gallery-screen` readability rules override earlier smaller type. For example, app body copy is **14px**, buttons **15px**, fields **16px** and navigation labels **10px** in the current source.

[design/tokens.json](../design/tokens.json) deliberately separates **`rawCss`** from **`flutterRecommendations`**. Raw entries name their CSS selector and context; recommendations are a proposed semantic model, not generated or tested Flutter code. The extraction uses source inspection and cascade reasoning, not browser-computed screenshots. File hashes and the source commit identify the exact reference.

## Colour: semantic roles, two complete themes

These are effective app colours after the relevant overrides, rather than just the root variable names. Component exceptions remain in the token file and source CSS.

| Role | Light | Dark |
|---|---|---|
| App canvas | `#FFFFFF` | `#18191D` |
| Raised surface token | `#F3F3F5` | `#24252B` |
| Text field fill | `#F7F7F9` | `#24252B` |
| Sheet fill | `#FFFFFF` | `#1E1F24` |
| Main text | `#202124` | `#F5F3F1` |
| Body copy | `#70707D` | `#AAA8B2` |
| Field labels | `#41414D` | `#E5E0E4` |
| Brand accent | `#FA634F` | `#FF907F` |
| Primary button / label | `#CF4131` / white | `#CF4131` / white |
| Accent container / selected chip text | `#FFF0EC` / `#B43C2D` | `#372622` / `#FF907F` |
| General divider token | `#EBEBEE` | `#35353D` |
| Active navigation | `#CD4937` | `#FF907F` |
| Outgoing message | `#CF4131` | `#B93F30` |

Use separate roles for **brand accent** and **filled-action background**. Replacing the darker button colour with the lighter accent would change both appearance and legibility. Likewise, `--muted` is not the final colour of every secondary label. Menu details, captions, warnings and the introduction have their own overrides.

A suitable Flutter mapping is an explicit light/dark colour scheme plus a small app-specific theme extension for photos, chat bubbles, accent containers and the story. Keep welcome and match screens dark in both modes (`#202124` in Light, `#151619` in Dark). Change surfaces and labels around photographs; preserve the photographs themselves. Do not implement Dark by filtering or inverting the whole screen.

Appearance offers **System, Light and Dark**, with System the default. Persist the preference, follow device changes only while System is selected, and apply it to every screen, sheet and introduction. The source resolves appearance before drawing the page; pursue the same flash-free startup in Flutter. Encode CSS `#RRGGBBAA` carefully when converting to Dart ARGB: the channel order differs.

## Typography and verified font assets

The active web face is **Plus Jakarta Sans, normal, variable weight 400–800**. The CSS uses intermediate weights including 450, 650 and 750. It does not load the legacy serif/italic assets. Preserve normal upright text throughout, including words marked with `<em>` in older markup.

| Style | Current CSS reference | Native starting point |
|---|---|---|
| Section title | 29px base; 31px mobile; 800; 1.13 line height | 31 logical pixels, weight 800 |
| Setup headline | 36px base; 39px mobile; 33px compact | Responsive 33–39, weight 800 |
| Body copy | 14px; 450; 1.65 line height | 14, variable weight 450 |
| Primary action | 15px; 750 | 15, variable weight 750 |
| Inputs / labels | 16px / 14px | 16 / 14 |
| Menu label / detail | 14px / 12px | 14 / 12 |
| Message text | 14px; 1.6 line height | 14 with content-led height |
| Profile age | 43px base; 46px mobile; 800 | 43–46 according to card space |
| Navigation label | 10px; 700 | Start at 10; honour text scaling |

The prototype’s font is a **Latin WOFF2 web subset**, not a prepared native asset. Flutter’s official documentation lists TTF/OTF/TTC and notes platform limitations for WOFF/WOFF2; the FontLoader API specifically documents OTF/TTF input. That does not justify claiming WOFF2 fails identically on every mobile platform. Use the supplied native TTF instead. Sources: [Flutter custom fonts](https://docs.flutter.dev/cookbook/design/fonts), [TextStyle font support](https://api.flutter.dev/flutter/painting/TextStyle-class.html), [FontLoader](https://api.flutter.dev/flutter/services/FontLoader/addFont.html).

The handoff includes [PlusJakartaSans-Variable.ttf](../design/flutter-assets/fonts/PlusJakartaSans-Variable.ttf), fetched from official Google Fonts, its matching [OFL.txt](../design/flutter-assets/fonts/OFL.txt) and [source metadata](../design/flutter-assets/fonts/source.json). The verified file has a weight axis of 200–800; use 400–800 for this design. This is an additional official asset, not a renamed or converted WOFF2. Declare it correctly in the native project and retain the licence. Use the verified variable axis for intermediate weights; if selecting static faces instead, review the approximation explicitly. Flutter documents variable-font control through `FontVariation`; do not rely on synthesised bold/italic to imitate a missing face. See [Flutter typography](https://docs.flutter.dev/ui/design/text/typography).

No native font rendering or Flutter build has been verified by this document. Test the loaded face, intermediate weights, accents and chat glyph fallback on target devices.

## Layout, spacing and components

The following are **reference dimensions**, not an instruction to scale the entire web phone as a bitmap.

| Component | Current CSS |
|---|---|
| Standard page | 24px mobile horizontal padding; Discover 17px; setup 25px |
| Primary button | Minimum height 52px; radius 30px |
| Input | Minimum height 54px; radius 14px; 15px padding |
| Photo card | Radius 24px; flexible height; no fixed aspect ratio |
| Swipe controls | Mobile Like 68px, Pass 58px, side controls 37px; smaller on short screens |
| Sheet | Top corners 27px; 23px side padding; scrollable |
| Timing controls | Four columns; 5px gaps; minimum 44px height, delay choices 59px |
| Chat bubble | Maximum 84% width; 13×15px padding; 16px corners with a 5px trailing corner |
| Bottom navigation | Mobile height 68px plus bottom inset; 23px icons |

Build a compact spacing scale of **4, 8, 12, 16, 20, 24 and 32 logical pixels** as a Flutter recommendation. Preserve optical alignment where the source uses an intermediate value. Provide at least 48 logical pixels of interactive area as a handoff target, even around smaller visible icons.

Keep card proportions responsive to available space, with image cover-cropping and per-photo focal position. Preserve the four-photo indicator, tap-to-page regions, age overlay and contrast gradient. Likes You uses blurred photo previews; the supplied blur is a visual reference, not an access-control mechanism.

Respect native safe areas and keyboard insets. Let setup, settings, reports, sheets and the introduction scroll. Allow labels and body text to grow with system text size; expand components or reflow grids before shrinking text. Avoid copying the prototype’s fixed 390px device frame, gallery scaling or browser viewport subtraction into production layout.

## Motion and accessible equivalents

The general CSS uses `cubic-bezier(.2,.75,.2,1)`, approximately 180ms button transitions, 240ms page entry and 280ms sheet/card transitions. Treat these as timing references when tuning native motion.

The introduction lasts **27.4 seconds**, with chapter starts at **0, 6.2, 10.6, 16.4 and 21.2 seconds**: Cross paths → Both fit → Give it time → Discover → Say hello. Rebuild its vector scene and state transitions; it is not a supplied video. Preserve its warmer light palette and dusk dark palette, separately recorded in the tokens.

Reduced motion replaces continuous movement with static chapter poses. The mandatory first viewing remains pausable and completes only after the required visible playback; optional Profile replay exposes chapter selection. Keep narration and progress understandable without motion. The sample clock illustrates a 1-hour/2-hour choice, while settings support delays up to one day. Do not mistake the example for a restriction on the product rules. Source: [how-it-works.js](../prototype/dist/how-it-works.js) and its stylesheet.

Before accepting the native translation, compare the same screen in both themes with normal and enlarged text, keyboard open, a short viewport and reduced motion. Source dimensions and colour samples do not constitute cross-platform rendering or accessibility certification.
