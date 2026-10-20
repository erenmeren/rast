# rast Mock App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A complete, navigable native rast app (Flutter, iOS + Android) running on fictional mock data, with every screen, sheet, rule and the introduction animation from the handoff.

**Architecture:** Feature-based Flutter app. Pure Dart rules in `lib/core/rules`. Riverpod `Notifier`s own app state and talk to repository interfaces whose only implementations today are in-memory mocks (plus `shared_preferences` for device-local settings). go_router with a four-branch `StatefulShellRoute` and one redirect guard for session / setup / intro.

**Tech Stack:** Flutter 3.47.7 stable, Dart 3.13.5, flutter_riverpod, go_router, shared_preferences, image_picker, flutter_svg, flutter_test.

**Spec:** `docs/superpowers/specs/2026-10-20-rast-mock-app-design.md`, which points at `rast-flutter-handoff/` (docs, tokens, prototype source). Executors read both. Exact copy comes from `rast-flutter-handoff/prototype/dist/app.js` and `how-it-works.js`; layout values from `docs/06_DESIGN_SYSTEM.md`, `design/tokens.json`, `prototype/dist/v2.css`, `dark-mode.css`, `how-it-works.css`.

## Global Constraints

- English interface only. Plus Jakarta Sans, weights 400–800, **never italic**.
- Four tabs in this order: Discover · Likes You · Chats · Profile. No fifth tab.
- `UPDATE_INTERVAL_SECONDS = [15, 30, 45, 60, 75, 90, 105, 120]`, default 30. `REVEAL_DELAY_HOURS = [0, 1, 2, 4, 6, 12, 18, 24]`, default 2. Effective delay = max of both; invalid value falls back to 2.
- Encounter distance `<= 20` metres between centres. `MIN_AGE = 18`, `MAX_PLAUSIBLE_AGE = 130` (prototype input guard, provisional). Ages `>= 99` display as `99+`; max preference 99 means unbounded.
- Deck order shuffled once per session (Fisher–Yates), stable across rebuilds, tabs, photo taps and filter changes.
- Never show exact crossing time, distance, map or an unrevealed person.
- Mock OTP `246810` lives only in `MockAuthRepository`.
- Light and dark themes for every screen and sheet. Welcome and Match stay dark in both modes (`#202124` light, `#151619` dark).
- Colour tokens (light / dark): canvas `#FFFFFF`/`#18191D`, raised `#F3F3F5`/`#24252B`, input fill `#F7F7F9`/`#24252B`, input border `#EEEEF2`/`#3C3B45`, sheet `#FFFFFF`/`#1E1F24`, text `#202124`/`#F5F3F1`, body `#70707D`/`#AAA8B2`, label `#41414D`/`#E5E0E4`, menu detail `#7C7C89`/`#AAA8B2`, primary `#CF4131` both, on-primary white, primary hover `#BA3628`/`#B83829`, brand accent `#FA634F`/`#FF907F`, accent container `#FFF0EC`/`#372622`, on accent container `#B43C2D`/`#FF907F`, outline `#EBEBEE`/`#35353D`, nav active `#CD4937`/`#FF907F`, nav inactive `#7C7C89`/`#A7A1AE`, incoming bubble `#F0F0F4`/`#2A272F`, on incoming `#565662`/`#E1D9E4`, outgoing bubble `#CF4131`/`#B93F30`, conversation canvas `#FCFCFD`/`#18191D`, error `#D7443D`/`#FF8A80`.
- Dimensions: page padding 24 (Discover 17, setup 25); primary button min height 52, radius 30; input min height 54, radius 14; photo card radius 24; Like button 68, Pass 58, side controls 37; sheet top radius 27, side padding 23; timing grid 4 columns, 5px gap, min height 44 (delay 59); chat bubble max 84% width, padding 13×15, radius 16 with 5 trailing corner; bottom nav 68 + safe area, 23px icons, 10px/700 labels; spacing scale 4, 8, 12, 16, 20, 24, 32; min touch target 48.
- Type: section title 31/800, setup headline 33–39/800, body 14/450 line-height 1.65, primary action 15/750, inputs 16, labels 14, menu label 14, menu detail 12, message 14, profile age 43–46/800, nav label 10/700.
- Motion references: ease `cubic-bezier(.2,.75,.2,1)`, buttons 180 ms, page entry 240 ms, sheets/cards 280 ms. Intro: 27.4 s, chapters at 0, 6.2, 10.6, 16.4, 21.2 s.
- Commit after every task with a conventional message and the Co-Authored-By trailer.

## Review Focus

1. **Age input "18.5", "17", "", "131", " 25 "**: setup refuses non-integers, under 18 and over 130 with the prototype's exact error strings; trimmed "25" is accepted. Test in Task 7.
2. **Remove connection while that conversation is open, then press back**: the conversation route must not reopen the removed thread; it lands on Chats. Test in Task 12.
3. **Appearance set to Light, then the OS switches to dark**: the app stays Light. With System, it follows. Test in Task 3.
4. **Intro backgrounded at 10 s, resumed 1 minute later**: watched time is still 10 s, playback resumes, Start exploring stays disabled until 27.4 s of visible playback. Test in Task 8.
5. **Rewind after the previously passed person was blocked**: Rewind skips them and reports "No passes to rewind yet." when nothing eligible remains. Test in Task 9.

---

### Task 1: Project scaffold, dependencies and assets

**Files:**
- Create: Flutter project at repo root (`pubspec.yaml`, `lib/main.dart`, `android/`, `ios/`, `analysis_options.yaml`)
- Create: `assets/fonts/PlusJakartaSans-Variable.ttf`, `assets/fonts/OFL.txt`, `assets/icons/*.svg` (36), `assets/photos/portrait-1..8.jpg`, `assets/photos/city.jpg`, `assets/photos/credits.json`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Produces: asset paths `assets/icons/<name>.svg`, `assets/photos/portrait-N.jpg`, `assets/photos/city.jpg`; font family `PlusJakartaSans`.

- [ ] **Step 1: Create the project**

Run from repo root: `flutter create --org app.rast --project-name rast --platforms android,ios .` Delete the generated `test/widget_test.dart` and the counter body of `lib/main.dart` (replace with `runApp(const Placeholder())` for now).

- [ ] **Step 2: Add dependencies**

Run: `flutter pub add flutter_riverpod go_router shared_preferences image_picker flutter_svg` then `flutter pub get`. Record the resolved versions in `docs/superpowers/plans/decision-log.md` under "Dependencies".

- [ ] **Step 3: Copy assets and declare them**

Copy from `rast-flutter-handoff/design/flutter-assets/fonts/`, `design/icons/`, `prototype/dist/assets/`. In `pubspec.yaml` declare `assets/icons/`, `assets/photos/` and the font:

```yaml
fonts:
  - family: PlusJakartaSans
    fonts:
      - asset: assets/fonts/PlusJakartaSans-Variable.ttf
```

- [ ] **Step 4: Write the smoke test**

```dart
testWidgets('app boots', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: Placeholder()));
  expect(find.byType(Placeholder), findsOneWidget);
});
```

- [ ] **Step 5: Verify**

Run: `flutter analyze && flutter test`. Expected: "No issues found!" and "All tests passed!".

- [ ] **Step 6: Commit** `chore: scaffold flutter project with assets and dependencies`

---

### Task 2: Domain rules in Dart

**Files:**
- Create: `lib/core/rules/rules.dart`
- Test: `test/core/rules_test.dart`

**Interfaces:**
- Produces:
  - `const int minAge = 18; const int maxPlausibleAge = 130; const double encounterRadiusMeters = 20; const int defaultDelayHours = 2;`
  - `const List<int> updateIntervalSeconds = [15, 30, 45, 60, 75, 90, 105, 120]; const List<int> revealDelayHours = [0, 1, 2, 4, 6, 12, 18, 24];`
  - `List<T> shuffleIds<T>(List<T> ids, {Random? random})` — Fisher–Yates on a copy; input unchanged.
  - `String ageLabel(int age)` → `'99+'` when `age >= 99`.
  - `bool isAdultAge(int? age)` → `age != null && age >= 18 && age <= 130`.
  - `bool ageInRange(int age, int min, int max)` — `max == 99` means unbounded; false when `max < min` or any negative.
  - `int effectiveDelay(int? a, int? b)` — invalid → 2, then max.
  - `bool canRevealEncounter({required double distanceMeters, required DateTime encounterAt, required DateTime now, required int? delayA, required int? delayB, required int? ageA, required int? ageB, required bool visibleA, required bool visibleB, required bool mutualPreferences, bool blocked = false, bool disconnected = false, required bool accurate})`.
  - `String delayLabel(int hours)` → `'Immediately'`, `'1 hour'`, `'2 hours'`, …, `'1 day'`; `String delayChipLabel(int hours)` → same but `'Instant'` for 0.
  - `String intervalLabel(int seconds)` → `'15 sec'`, `'1 min'`, `'1m 15s'`, `'2 min'`.

- [ ] **Step 1: Write failing tests** porting `prototype/checks/rules.test.mjs`:

```dart
test('99+ is a display and range boundary', () {
  expect(ageLabel(98), '98'); expect(ageLabel(99), '99+'); expect(ageLabel(105), '99+');
  expect(ageInRange(105, 18, 99), isTrue); expect(ageInRange(99, 18, 98), isFalse); expect(ageInRange(17, 18, 99), isFalse);
});
test('longer delay wins, invalid falls back to 2', () {
  expect(effectiveDelay(0, 2), 2); expect(effectiveDelay(1, 0), 1); expect(effectiveDelay(0, 0), 0);
  expect(effectiveDelay(null, 0), 2); expect(effectiveDelay(-1, 0), 2);
  for (final a in revealDelayHours) { for (final b in revealDelayHours) { expect(effectiveDelay(a, b), max(a, b)); } }
  for (final bad in [3, 5, 23, 25]) { expect(effectiveDelay(bad, 0), 2); }
});
// encounter fixture: distance 20, encounterAt 2026-10-17T10:00Z, now 12:00Z, delayA 0, delayB 2, ages 24/28, all gates true
test('encounter needs <=20 m and the full mutual delay', () {
  expect(reveal(), isTrue);
  expect(reveal(distanceMeters: 40), isFalse); expect(reveal(distanceMeters: 20.001), isFalse); expect(reveal(distanceMeters: -1), isFalse); expect(reveal(distanceMeters: double.nan), isFalse);
  expect(reveal(now: DateTime.utc(2026, 10, 17, 11, 59, 59, 999)), isFalse);
  expect(reveal(delayB: 0, now: DateTime.utc(2026, 10, 17, 10)), isTrue);
  expect(reveal(delayA: 0, delayB: 24, now: DateTime.utc(2026, 10, 18, 9, 59, 59, 999)), isFalse);
  expect(reveal(delayA: 0, delayB: 24, now: DateTime.utc(2026, 10, 18, 10)), isTrue);
  expect(reveal(delayA: 24, delayB: 0, now: DateTime.utc(2026, 10, 18, 10)), isTrue);
});
test('all gates apply', () {
  for (final f in [ () => reveal(ageA: 17), () => reveal(ageB: 17), () => reveal(ageA: 131), () => reveal(visibleA: false), () => reveal(visibleB: false), () => reveal(mutualPreferences: false), () => reveal(blocked: true), () => reveal(disconnected: true), () => reveal(accurate: false) ]) { expect(f(), isFalse); }
  expect(reveal(ageA: 105), isTrue);
});
test('shuffle keeps every id once and never mutates', () {
  const ids = ['e-90', 'e-10', 'e-70', 'e-20'];
  final out = shuffleIds(ids, random: Random(7));
  expect(out..sort(), [...ids]..sort()); expect(ids, ['e-90', 'e-10', 'e-70', 'e-20']);
  expect(shuffleIds(<String>[]), isEmpty); expect(shuffleIds(['only']), ['only']);
});
test('labels', () {
  expect(delayLabel(0), 'Immediately'); expect(delayLabel(1), '1 hour'); expect(delayLabel(2), '2 hours'); expect(delayLabel(24), '1 day'); expect(delayChipLabel(0), 'Instant');
  expect(intervalLabel(15), '15 sec'); expect(intervalLabel(60), '1 min'); expect(intervalLabel(75), '1m 15s'); expect(intervalLabel(120), '2 min');
});
```

- [ ] **Step 2: Run** `flutter test test/core/rules_test.dart` — expected: compile failure (symbols undefined).
- [ ] **Step 3: Implement** `lib/core/rules/rules.dart` with the signatures above.
- [ ] **Step 4: Run** the test — expected PASS.
- [ ] **Step 5: Commit** `feat(rules): port encounter, delay, age and shuffle rules with fixtures`

---

### Task 3: Theme, typography and persisted appearance

**Files:**
- Create: `lib/core/theme/rast_colors.dart`, `lib/core/theme/rast_theme.dart`, `lib/core/theme/appearance.dart`, `lib/core/storage/preferences_store.dart`
- Test: `test/core/theme_test.dart`

**Interfaces:**
- Produces:
  - `class RastColors extends ThemeExtension<RastColors>` with fields named after the Global Constraints tokens (`canvas, raised, inputFill, inputBorder, sheet, text, body, label, menuDetail, primary, onPrimary, primaryHover, accent, accentContainer, onAccentContainer, outline, navActive, navInactive, incomingBubble, onIncomingBubble, outgoingBubble, onOutgoingBubble, conversationCanvas, error, darkStage`), statics `RastColors.light`, `RastColors.dark`, extension `BuildContext.colors`.
  - `ThemeData rastTheme(Brightness b)` — Material 3 off, font family `PlusJakartaSans`, `TextTheme` built with `RastText` helpers.
  - `TextStyle rastStyle({required double size, required int weight, double? height, double? letterSpacing, Color? color})` using `FontVariation('wght', weight)` and `fontWeight` nearest bucket.
  - `enum Appearance { system, light, dark }`; `class AppearanceNotifier extends Notifier<Appearance>` with `Future<void> set(Appearance)` persisting under key `rast.appearance`; `final appearanceProvider = NotifierProvider<AppearanceNotifier, Appearance>`; `ThemeMode themeModeOf(Appearance)`.
  - `class PreferencesStore` wrapping `SharedPreferences` with `getString/setString/getInt/setInt/getBool/setBool/getStringList/setStringList/remove`; `final preferencesStoreProvider = Provider<PreferencesStore>` (overridden at bootstrap with the loaded instance).

- [ ] **Step 1: Failing tests**

```dart
test('light and dark tokens match the handoff', () {
  expect(RastColors.light.primary, const Color(0xFFCF4131)); expect(RastColors.dark.canvas, const Color(0xFF18191D)); expect(RastColors.dark.accent, const Color(0xFFFF907F));
});
test('no italic anywhere in the text theme', () {
  for (final s in rastTheme(Brightness.light).textTheme.toString().split(',')) { expect(s.contains('italic'), isFalse); }
});
test('appearance persists and maps to ThemeMode', () async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [preferencesStoreProvider.overrideWithValue(PreferencesStore(await SharedPreferences.getInstance()))]);
  await container.read(appearanceProvider.notifier).set(Appearance.dark);
  expect(container.read(appearanceProvider), Appearance.dark);
  expect(themeModeOf(Appearance.dark), ThemeMode.dark); expect(themeModeOf(Appearance.system), ThemeMode.system);
  final again = ProviderContainer(overrides: [preferencesStoreProvider.overrideWithValue(PreferencesStore(await SharedPreferences.getInstance()))]);
  expect(again.read(appearanceProvider), Appearance.dark);
});
testWidgets('explicit Light ignores platform dark', (tester) async {
  await tester.pumpWidget(MaterialApp(theme: rastTheme(Brightness.light), darkTheme: rastTheme(Brightness.dark), themeMode: themeModeOf(Appearance.light), home: Builder(builder: (c) => Text('x', style: TextStyle(color: c.colors.canvas)))));
  tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark; await tester.pump();
  expect(find.byType(Text), findsOneWidget);
  expect(Theme.of(tester.element(find.byType(Text))).brightness, Brightness.light);
});
```

- [ ] **Step 2: Run** — expected: compile failure.
- [ ] **Step 3: Implement** the four files. `rastTheme` sets `scaffoldBackgroundColor = colors.canvas`, `useMaterial3: false`, `splashFactory: NoSplash.splashFactory`, `bottomSheetTheme` with sheet colour and top radius 27, `extensions: [colors]`.
- [ ] **Step 4: Run** — PASS. Also `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(theme): rast colours, Jakarta typography and persisted appearance`

---

### Task 4: Shared UI components

**Files:**
- Create under `lib/core/ui/`: `rast_icon.dart`, `rast_logo.dart`, `buttons.dart`, `fields.dart`, `option_chip.dart`, `sub_header.dart`, `app_header.dart`, `info_box.dart`, `menu_row.dart`, `rast_switch.dart`, `empty_state.dart`, `rast_sheet.dart`, `toast.dart`, `age_range_slider.dart`, `timing_grid.dart`, `photo_image.dart`, `avatar.dart`, `pill.dart`
- Test: `test/core/ui_test.dart`

**Interfaces:**
- Produces:
  - `RastIcon(String name, {double size = 22, Color? color, double strokeWidth = 1.6})` — loads `assets/icons/$name.svg`, tints via `ColorFilter`; `mark` uses 26×24 viewBox.
  - `RastLogo({double size = 31, Color? color})` — mark icon + "rast" + coral dot, weight 800, letter-spacing −1.9.
  - `PrimaryButton({required String label, VoidCallback? onPressed, String trailingIcon = 'arrow', String? leadingIcon, bool dark = false})` min height 52, radius 30; `SecondaryButton`, `TextLinkButton({label, onPressed, bool fullWidth = false})`.
  - `RastTextField({controller, label, hint, keyboardType, inputFormatters, maxLength, autofillHints, onChanged, errorText, suffix})` fill/border/radius 14, min height 54; `FormError(String? message)` red 13px.
  - `OptionChip({required String label, required bool selected, required VoidCallback onTap})` with check icon when selected.
  - `SubHeader({required String title, VoidCallback? onBack, int step = 0})` renders five step bars when `step > 0`.
  - `AppHeader({required String action /* 'filters' | 'settings' */, required VoidCallback onAction, bool premium = false})` logo + optional PLUS mini + icon button.
  - `InfoBox({required String icon, required String strong, required String text})`; `SettingTip({icon, text})`.
  - `MenuRow({required String label, String? detail, required String icon, required VoidCallback onTap})`.
  - `RastSwitch({required bool value, required ValueChanged<bool> onChanged, String? semanticLabel})`.
  - `EmptyState({required String icon, required String title, required String text, String? actionLabel, VoidCallback? onAction})`.
  - `Future<T?> showRastSheet<T>(BuildContext, {required String title, required WidgetBuilder builder})` — modal bottom sheet, handle, title row with close button, top radius 27, side padding 23, scrollable, keyboard-aware.
  - `void showToast(BuildContext, String message)` — overlay pill with check icon for 3.8 s; also `SemanticsService.announce`.
  - `AgeRangeSlider({required int minAge, required int maxAge, required void Function(int min, int max) onChanged})` — one `RangeSlider` 18…99, heading "Age range" + `"$min–${ageLabel(max)}"`, endpoints 18 / 99+, min ≤ max enforced.
  - `TimingGrid<T>({required List<T> values, required T selected, required String Function(T) label, String? Function(T)? note, required ValueChanged<T> onSelect, double minHeight = 44})` — 4 columns, 5 gap.
  - `PhotoImage(String src, {BoxFit fit = BoxFit.cover, Alignment alignment = Alignment.center})` — `assets/` → `Image.asset`, otherwise `Image.file`.
  - `Avatar(String src, {double size = 44, bool highlighted = false})`; `Pill({required String label, bool accent = false, String? icon, bool dot = false, VoidCallback? onTap})`.

- [ ] **Step 1: Failing widget tests**: `PrimaryButton` disabled when `onPressed == null`; `OptionChip` shows check only when selected; `AgeRangeSlider` reports clamped `min <= max`; `TimingGrid` renders 8 children in 4 columns; `showRastSheet` shows title and closes on the close button; `SubHeader(step: 3)` renders 3 "done" bars (use `Key('step-bar-$n-done')`).
- [ ] **Step 2: Run** — compile failure.
- [ ] **Step 3: Implement** each widget with the Global Constraints dimensions; read `v2.css`/`dark-mode.css` for the exact selectors (`.primary`, `.field`, `.option-chip`, `.menu-row`, `.sheet`, `.toast`, `.dual-range`, `.timing-options`, `.switch`, `.empty-state`).
- [ ] **Step 4: Run** tests + analyze — PASS.
- [ ] **Step 5: Commit** `feat(ui): shared rast components`

---

### Task 5: Models, mock repositories and app state

**Files:**
- Create: `lib/core/models/person.dart`, `models/profile.dart`, `models/preferences.dart`, `models/settings.dart`, `models/thread.dart`, `models/safety.dart`, `models/session.dart`
- Create: `lib/data/repositories.dart` (abstract), `lib/data/mock/mock_people.dart`, `mock/mock_auth_repository.dart`, `mock/mock_safety_repository.dart`, `mock/mock_intro_repository.dart`, `mock/mock_entitlement_repository.dart`
- Create: `lib/app/providers.dart`, `lib/features/auth/session_notifier.dart`, `lib/features/profile/profile_notifier.dart`, `lib/features/profile/preferences_notifier.dart`, `lib/features/profile/settings_notifier.dart`, `lib/features/safety/safety_notifier.dart`, `lib/features/discovery/deck_notifier.dart`, `lib/features/chat/threads_notifier.dart`, `lib/features/premium/premium_notifier.dart`, `lib/features/intro/intro_notifier.dart`
- Test: `test/features/state_test.dart`

**Interfaces:**
- Produces:
  - `enum Gender { woman, man, nonbinary, self }` with `label` ("Woman", "Man", "Non-binary", "Self-describe"); `enum Interest { everyone, women, men, nonbinary }` with `label` ("Everyone", "Women", "Men", "Non-binary people") and `bool matches(Gender)` (everyone → true; women→woman; men→man; nonbinary→nonbinary; self → only everyone — provisional).
  - `class Person { String id; int age; Gender gender; String photo; int delayHours; int hoursAgo; double distanceMeters; bool likesYou; Set<Interest> interests; int minAge; int maxAge; }` and `List<PhotoFrame> albumOf(Person)` → 4 frames `(src, zoom, alignment)`: `(photo, 1.0, Alignment(0,-0.34))`, `(photo, 1.3, Alignment(0,-0.56))`, `(city, 1.0, center)`, `(photo, 1.08, Alignment(0,-0.04))`.
  - `mockPeople` = the six prototype fixtures (`p1` 27 woman portrait-1 delay 2 ago 3 dist 12 likesYou; `p2` 29 man portrait-4 d1 ago4 18 no; `p3` 26 nonbinary portrait-6 d2 ago5 9 yes; `p4` 31 man portrait-3 d2 ago5 15 no; `p5` 28 woman portrait-2 d1 ago6 11 yes; `p6` 30 man portrait-5 d2 ago7 20 yes; all interests {everyone}, 18–99). `samplePhotos = [portrait-7, portrait-7, city, portrait-7]`. `seedThreads()` = `t1` with `p3` unread 2 and the three prototype messages; `t2` with `p2` unread 0 and two messages.
  - `class Profile { int? age; Gender? gender; String customGender; bool showGender; List<String?> photos /* length 4 */; String dial; String phone; }` with `int get photoCount`, `bool get photosComplete`, `String get primaryPhoto` (first non-null or portrait-7).
  - `class Preferences { Set<Interest> interests; int minAge; int maxAge; }` `toggle(Interest)` semantics: picking everyone clears others; picking a specific clears everyone; `String get summary` → `"23–36 years · Everyone"`.
  - `class Settings { int intervalSeconds = 30; int delayHours = 2; bool visible = true; bool locationEnabled = false; bool notifications = true; }` persisted keys `rast.interval`, `rast.delay`, `rast.notifications`.
  - `class SafetyState { Set<String> blocked; Set<String> disconnected; List<Report> reports; }`, `class Report { String personId; String reason; }`, `const reportReasons = ['May be under 18', 'Fake profile or someone else’s photos', 'Harassment or inappropriate behaviour', 'Scam or spam', 'Another reason']`.
  - `enum SessionPhase { signedOut, onboarding, introPending, active }`; `class Session { SessionPhase phase; bool verified; }`.
  - Abstract repos: `AuthRepository { Future<void> sendCode(String dial, String phone); Future<bool> verify(String code); }`, `SafetyRepository { Future<SafetyState> load(); Future<void> save(SafetyState); }`, `IntroRepository { Future<String?> status(); Future<void> set(String status); }` (values `pending`/`complete`), `EntitlementRepository { Future<bool> isPremium(); Future<void> setPremium(bool); }`, `SessionRepository { Future<Session> load(); Future<void> save(Session); Future<void> clear(); }`.
  - Notifiers (all `Notifier<T>`), with these methods:
    - `SessionNotifier`: `startSignup()`, `beginPhone()`, `markVerified()`, `finishSetup({required bool locationGranted})` (validates photos complete, verified, adult age, gender, interests; sets `introPending` if intro not complete else `active`), `completeIntro()`, `logOut()`, `deleteAccount()`.
    - `ProfileNotifier`: `setAgeInput`, `setGender`, `setCustomGender`, `setShowGender`, `setPhoto(int slot, String? src)`, `useSamplePhotos()`, `setPhone(dial, phone)`.
    - `PreferencesNotifier`: `toggle(Interest)`, `setRange(min, max)`, `replace(Preferences)`.
    - `SettingsNotifier`: `setInterval(int)`, `setDelay(int)`, `setVisible(bool)`, `setLocation(bool)`, `setNotifications(bool)`.
    - `SafetyNotifier`: `block(id)`, `unblock(id)`, `disconnect(id)`, `report(id, reason)`, `bool isUnavailable(id)`, `reset()`.
    - `DeckNotifier` state `DeckState { List<String> order; Set<String> passed; Set<String> liked; List<String> history; String? focus; int photoIndex; }` with `pass(id)`, `like(id)`, `rewind()` → returns restored id or null (skips unavailable), `focus(id)`, `nextPhoto()`, `prevPhoto()`, `resetPhoto()`, `reshuffle()`.
    - `ThreadsNotifier`: `Thread? ensureThread(personId)`, `send(threadId, text)` (trim, 1000 cap, time `HH:mm`), `markRead(threadId)`, `removePerson(personId)`, `reset()`.
    - `PremiumNotifier`: `activatePreview()`, `end()`.
    - Derived providers in `lib/features/discovery/eligibility.dart`: `eligiblePeopleProvider` (applies `canRevealEncounter` with `encounterAt = sampleTime - hoursAgo`, `visibleA = settings.visible && settings.locationEnabled && profile.photosComplete`, mutual preference check both ways, blocked/disconnected from safety, `accurate: true`, excluding passed/liked/threaded), `incomingLikesProvider`, `currentPersonProvider`, `unreadBadgeProvider`.
    - `removePersonEverywhere(WidgetRef/ Ref, String id, {bool block = false})` in `lib/features/safety/remove_person.dart` — block if asked; disconnect when not blocking or when a thread existed; remove thread, liked, passed, history, focus.

- [ ] **Step 1: Failing tests**: deck order is a permutation of six ids and unchanged after `nextPhoto()`; `eligiblePeopleProvider` excludes `p2` when preferences are `{women}`; a person with `delayHours 2` and `hoursAgo 1` is hidden; blocked person disappears from eligible and incoming likes; `removePersonEverywhere(p3)` deletes thread `t1` and adds `p3` to disconnected; `block` of an unmatched person does not add to disconnected; `unblock` keeps disconnected; `rewind()` skips a blocked id and returns null when empty; `finishSetup` fails with three photos; `send` trims and caps at 1000 chars; preferences toggle rules.
- [ ] **Step 2: Run** — compile failure.
- [ ] **Step 3: Implement** models, mocks (`MockAuthRepository.verify` returns `code == '246810'`; `MockSafetyRepository` persists `rast.safety.blocked`, `rast.safety.disconnected`, `rast.safety.reports` as string lists; `MockSessionRepository` key `rast.session`), notifiers and `providers.dart` which exposes `authRepositoryProvider`, `safetyRepositoryProvider`, `introRepositoryProvider`, `entitlementRepositoryProvider`, `sessionRepositoryProvider`, each defaulting to the mock.
- [ ] **Step 4: Run** tests + analyze — PASS.
- [ ] **Step 5: Commit** `feat(state): models, mock repositories and riverpod notifiers`

---

### Task 6: Router, shell and bottom navigation

**Files:**
- Create: `lib/app/router.dart`, `lib/app/shell.dart`, `lib/app/app.dart`, `lib/app/bootstrap.dart`; modify `lib/main.dart`
- Create placeholder pages for every route in their feature folders (a `Scaffold` with the route name) to be replaced in later tasks
- Test: `test/app/router_test.dart`

**Interfaces:**
- Produces:
  - Routes: `/welcome`, `/auth/phone`, `/auth/verify`, `/setup/about`, `/setup/preferences`, `/setup/photos`, `/setup/location`, `/intro`; shell branches `/discover` (+ `/discover/people/:id`), `/likes` (+ `/likes/people/:id`, `/likes/plus`), `/chats` (+ `/chats/:threadId`), `/profile` (+ `/profile/location`, `/profile/photos`, `/profile/safety`, `/profile/how-it-works`, `/profile/plus`); top-level `/matches/:personId`.
  - `GoRouter buildRouter(Ref ref)` with `redirect`: `signedOut` → only `/welcome` and `/auth/*` and `/setup/*` allowed, else `/welcome`; `onboarding` → `/auth/*`, `/setup/*` allowed; `introPending` → everything redirects to `/intro`; `active` → `/welcome`, `/auth/*`, `/setup/*`, `/intro` redirect to `/discover`. `refreshListenable` driven by `sessionProvider`.
  - `RastShell` = `Scaffold` with `StatefulNavigationShell` body and `RastBottomNav` (4 items, icons `mark`, `heart`, `chat`, `user`, labels "Discover", "Likes You", "Chats", "Profile", likes count badge, chats unread dot). Hidden on `/chats/:threadId`.
  - `bootstrap()` in `bootstrap.dart`: `WidgetsFlutterBinding.ensureInitialized()`, load `SharedPreferences`, read appearance **before** `runApp`, `ProviderScope(overrides: [preferencesStoreProvider.overrideWithValue(...)], child: RastApp())`.
  - `RastApp` = `MaterialApp.router` with both themes, `themeMode` from `appearanceProvider`, `title: 'rast'`.

- [ ] **Step 1: Failing tests**: signed-out start shows Welcome; `active` session start shows Discover with 4 nav items in order; `introPending` session trying `/discover` lands on `/intro`; tapping "Chats" nav shows Chats placeholder.
- [ ] **Step 2: Run** — fails.
- [ ] **Step 3: Implement** router, shell, nav, bootstrap, app.
- [ ] **Step 4: Run** tests + analyze — PASS. `flutter run` not required yet.
- [ ] **Step 5: Commit** `feat(app): go_router shell with four tabs and session guards`

---

### Task 7: Onboarding screens

**Files:**
- Create: `lib/features/auth/welcome_page.dart`, `auth/phone_page.dart`, `auth/verify_page.dart`, `lib/features/onboarding/about_you_page.dart`, `onboarding/preferences_page.dart`, `onboarding/preferences_form.dart`, `onboarding/photos_page.dart`, `onboarding/photo_grid.dart`, `onboarding/location_permission_page.dart`, `lib/features/profile/sheets/terms_sheet.dart`, `profile/sheets/privacy_sheet.dart`
- Test: `test/features/onboarding_test.dart`

**Interfaces:**
- Consumes Task 4 widgets, Task 5 notifiers.
- Produces: `PreferencesForm({required Preferences value, required ValueChanged<Preferences> onChanged})` reused by the filters sheet; `PhotoGrid({required List<String?> photos, required void Function(int) onPick, required void Function(int) onRemove})`; `showTermsSheet(context)`, `showPrivacySheet(context)`.

Copy and behaviour per `app.js` `welcomeScreen…permissionScreen` and the screen map:
- Welcome: dark stage, two portraits (portrait-1, portrait-4), badge "A LITTLE CLOSER.", floating note "You crossed paths", title "Good things happen nearby." with "nearby." in accent, copy "Meet the people life brings your way. Make the next move yours.", primary "Let's get you out there", text "Already here? Log in", footer "18+ only. By continuing, you agree to our Terms and Privacy information."
- Phone: SubHeader "Getting started" step 1, kicker "LET'S MAKE THIS SIMPLE", "Your number. Your way in.", dial dropdown `+44 +1 +90 +49`, placeholder `7700 900 123`, help "Your number is never shown on your profile.", info box lock / "A private first step." / "Your phone number is used to help verify your account.", primary "Send code". Validation: `+90` → `^[1-9]\d{9}$` else `^\d{7,14}$` after stripping non-digits; errors "Enter a 10-digit number without the leading zero." / "Enter a valid phone number.". On success toast "Demo SMS code: 246810. No real SMS is sent." and go to verify.
- Verify: "Verify your number" step 1, "Check your messages.", copy "Enter the six-digit code sent to **{dial} {phone}**.", one 6-digit numeric field with `autofillHints: [AutofillHints.oneTimeCode]`, links "Change number" / "Send again" (toast "Demo verification code: 246810. No SMS is sent."), primary "Verify"; wrong code error "That code does not match. Use 246810 for this prototype."
- About you: "About you" step 2, "THE ESSENTIALS", "A little about you.", age field + "years old", help "You must be 18 or older. Ages 99 and up display as 99+.", gender chips (none preselected), self-describe field "In your own words" max 50 when `self`, checkbox "Show my gender on my profile.", Continue. Errors: under 18 → "You must be 18 or older to use rast."; non-integer/empty/>130 → "Enter a valid whole-number age from 18 to 130."; no gender → "Select your gender to continue."; self without text → "Describe your gender in your own words."
- Preferences: "Your preferences" step 3, "Your kind of connection.", `PreferencesForm` (label "Who would you like to meet?", chips Everyone/Women/Men/Non-binary people, help "Choose more than one. Everyone includes all gender identities.", AgeRangeSlider, info box "It goes both ways." / "You will only see people when you match each other's age and gender preferences."), Continue requires ≥1 interest ("Choose at least one dating preference.").
- Photos: "Your first impression" step 4, "Four photos. All you.", copy, 4 slots numbered 01–04 with "MAIN PHOTO" badge on slot 1, remove buttons, "Four photos required." / "N of 4 added", Continue disabled until 4, footnote "Use clear, recent photos of yourself.". Picker via `image_picker` gallery; in `kDebugMode` a `TextLinkButton('Use sample photos')`.
- Location: "One last thing" step 5, "Out there. Closer than ever.", copy "Meet people you have crossed paths with, within approximately 20 metres.", orbit illustration, two permission items (locate: "Catch the everyday encounters" / "Background location helps find crossings even when the app isn't open."; shield: "Your location stays yours" / "No exact locations are shared. Profiles appear after 2 hours by default."), primary "Enable location", text "Not now". Both call `finishSetup` (granted sets `locationEnabled` and `visible` true). No real permission request in this milestone.

- [ ] **Step 1: Failing widget tests** (pump the real router with a signed-out session): Welcome CTA goes to phone; phone rejects "123" with the exact error; verify rejects "000000" and accepts "246810"; about-you rejects "17", "18.5", "", "131" with the exact strings and accepts " 25 "; preferences blocks Continue with no interest; photos Continue disabled at 3 photos and enabled at 4 (use `useSamplePhotos`); "Not now" with a complete profile moves session to `introPending`.
- [ ] **Step 2: Run** — fails.
- [ ] **Step 3: Implement** the pages (layout from `v2.css` `.onboarding`, `.welcome*`, `.photo-grid`, `.upload-slot`, `.permission-*`).
- [ ] **Step 4: Run** tests + analyze — PASS.
- [ ] **Step 5: Commit** `feat(onboarding): welcome, phone, code, about you, preferences, photos, location`

---

### Task 8: How it works — required introduction and optional replay

**Files:**
- Create: `lib/features/intro/story_model.dart` (pure), `intro/story_controller.dart`, `intro/story_scene.dart` (CustomPainter world + overlays), `intro/how_it_works_page.dart`
- Test: `test/features/intro/story_model_test.dart`, `test/features/intro/story_controller_test.dart`, `test/features/intro/how_it_works_page_test.dart`

**Interfaces:**
- Produces:
  - `const howDurationMs = 27400; const howSteps = [HowStep(at: 0, label: 'Cross paths', title: 'Life brings you a little closer.', copy: 'Go about your day. When someone comes within about 20 metres, your paths can cross.'), …five, copied verbatim from how-it-works.js]; const howPosters = [5900, 9900, 14000, 20000, 27400];` scene labels `['OUT IN THE WORLD','THE FIT IS MUTUAL','PRIVACY SETS THE PACE','A NEW POSSIBILITY','THE NEXT MOVE IS YOURS']`.
  - `HowFrame howFrame(int ms)` → `{ time, a: Offset, b: Offset, distance, crossed, stage, wait, remaining, youLike, theyLike, chat }` reproducing the bezier/smooth maths of `howFrame` in `how-it-works.js` (SVG units; 4 units = 1 m).
  - `double during(int t, int start, int end)` smoothstep helper.
  - `class StoryController extends ChangeNotifier { StoryController({required bool required, required bool reducedMotion, TickerProvider? vsync}); int timeMs; int watchedMs; bool playing; bool complete; bool inView; void toggle(); void replay(); void setStep(int); void setVisible(bool); void tick(Duration elapsedSinceLast); }` — `tick` credits `min(elapsed, 100 ms)` to `watchedMs` in required mode and sets `complete` when `watchedMs >= 27400`; ignores ticks while `!inView || !playing`; in required + reduced motion the displayed frame is `howFrame(howPosters[stage])` while time still advances; optional + reduced motion: toggle advances to the next poster.
  - `HowItWorksPage({required bool required})` — layout and copy per `howMarkup`: header logo + "Illustrative demo" pill; eyebrow "ONE QUICK INTRODUCTION" (required) or "SMALL WORLD. GOOD TIMING."; "How a hello happens." with "happens." in coral; required message "Watch once. Then make your next move."; `StoryScene` 1:1 up to 338 tall; player row (Pause/Play/Replay/Next step/Complete labels, time "0:SS / 0:27", "Just this once" in required mode); 5 chapter buttons with progress bars (disabled in required); narration "01 / 05", title, copy; CTA "Watch to continue" (disabled) → "Start exploring" (required) or "Back to Profile" (optional); access note strings exactly as `paint()` sets them. Required mode wraps in `PopScope(canPop: false)`. Uses `WidgetsBindingObserver` to set `inView=false` on `paused/inactive/hidden`. Reduced motion from `MediaQuery.disableAnimationsOf(context)`. Palette: light paper `#FCFAF6`, ink `#292C33`, coral `#D8523E`; dark palette from `dark-mode.css` `.how-page` overrides.
  - On `complete` in required mode the page calls `introNotifier.complete()` then `sessionNotifier.completeIntro()` when the user taps Start exploring.

- [ ] **Step 1: Failing tests**:
  - `howFrame(0).stage == 0; howFrame(6200).stage == 1; howFrame(21200).stage == 4; howFrame(27400).chat == true; howFrame(6000).crossed == true` (persons reach ≤20 m at end of walk); `howFrame(0).crossed == false`.
  - Controller: 300 ticks of 100 ms in required mode → `complete`; a 5 s tick credits only 100 ms; ticks while `inView=false` credit nothing; `toggle()` pauses and resumes; optional `setStep(2)` sets `timeMs == 14000` and pauses.
  - Page: required mode shows disabled "Watch to continue"; after pumping 27.5 s of frames the button reads "Start exploring"; backgrounding via `tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused)` for 60 s then resuming leaves `watchedMs` unchanged; optional mode shows "Back to Profile" and enabled chapters.
- [ ] **Step 2: Run** — fails.
- [ ] **Step 3: Implement** model, controller (driven by a `Ticker` in the page), painter (port the SVG paths: roads, blocks, park, radius circle r=80 with dashed stroke, dashed connection line, two persons with "You" / "Someone" labels), overlay layers (crossing label, fit checks, wait clock with ring `dashoffset = 439.823 * wait` and `MM:SS` of `remaining` minutes, discover mini card, hello pair with like stamps and message "Hey. Coffee sometime?"), page.
- [ ] **Step 4: Run** tests + analyze — PASS.
- [ ] **Step 5: Commit** `feat(intro): native How it works story with required and replay modes`

---

### Task 9: Discover deck

**Files:**
- Create: `lib/features/discovery/discover_page.dart`, `discovery/profile_card.dart`, `discovery/card_actions.dart`, `discovery/swipe_controller.dart`
- Test: `test/features/discovery/discover_page_test.dart`

**Interfaces:**
- Consumes `currentPersonProvider`, `DeckNotifier`, `ThreadsNotifier`, `albumOf`.
- Produces: `ProfileCard({required Person person, required int photoIndex, required VoidCallback onPrev, required VoidCallback onNext, required VoidCallback onMenu, required VoidCallback onDetail, required void Function(SwipeDirection) onSwipe})`; `enum SwipeDirection { like, pass }`; `likePerson(WidgetRef ref, BuildContext context, Person p, {required String returnTo})` in `discovery/like_action.dart` — adds to liked; if `likesYou` ensures thread and goes `/matches/:id`, else toast "Like sent. A mutual like starts a conversation." and returns.

Behaviour: header `AppHeader(action: 'filters')`; heading "Discover" + "Real-life crossings. A fresh mix." + status orb (locate when active, pause otherwise, tap → `/profile/location`); card: hero photo from `albumOf(person)[photoIndex]` with zoom + alignment, 4 indicator bars, left/right tap zones (outer 36 %) for prev/next, top pill "You crossed paths", menu button, bottom: `ageLabel` 43–46/800 + "years old", "A familiar stranger.", tag "A real-life crossing", info button → `/discover/people/:id`; swipe: horizontal drag `> 12 px` and dominant starts drag, translate + rotate `dx/23` deg, stamp "LIKE"/"PASS" opacity `min(|dx|/130, 1)`, release `|dx| > 85` commits, 240 ms fly-out, taps suppressed for 350 ms after a drag; actions row: rewind (disabled when no history), pass 58, like 68, info (→ `/profile/how-it-works` optional story); privacy line "Your exact location stays private."; empty states: photos<4 → "Your photos come first." / "Add all four photos to discover new connections." / "Complete your photos" → `/profile/photos`; paused → "Taking a little breather." / "Your visibility is paused. Pick things up when you are ready." / "Resume encounters"; location off → "Let your paths cross." / "Enable location to discover people whose paths cross yours." / "Enable location" (location sheet); else "You're all caught up." / "New encounters appear once their privacy delay has passed." / "Adjust preferences" (filters sheet). Rewind toasts "Your last pass has been undone." or "No passes to rewind yet.".

- [ ] **Step 1: Failing tests**: with an active mock session the first card shows the first id of `deckOrder`; tapping the right edge advances the indicator and keeps the same person; tapping pass shows the next person and enables rewind; rewind restores the passed person; dragging 120 px right on a `likesYou` person navigates to `/matches/:id`; blocking the passed person then rewind shows "No passes to rewind yet."; with `visible=false` the paused empty state shows.
- [ ] **Step 2: Run** — fails.
- [ ] **Step 3: Implement** (CSS: `.profile-card`, `.hero-photo`, `.photo-indicators`, `.card-top`, `.card-bottom`, `.card-actions`, `.swipe-stamp`, `.status-orb`, `.discover-heading`).
- [ ] **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(discover): swipe deck with albums, actions and empty states`

---

### Task 10: Person detail, preferences sheet and encounter summary sheet

**Files:**
- Create: `lib/features/discovery/person_detail_page.dart`, `lib/features/profile/sheets/filters_sheet.dart`, `lib/features/discovery/encounter_summary_sheet.dart`
- Test: `test/features/discovery/person_detail_test.dart`

**Interfaces:**
- Produces: `PersonDetailPage({required String personId, required String origin /* 'discover' | 'likes' */})`; `showFiltersSheet(context, ref)` (draft `Preferences`, "Your kind of connection.", copy "A few preferences. More possibilities.", `PreferencesForm`, "Save preferences" → `replace` + `resetPhoto` + toast "Your dating preferences have been updated."; dismiss discards); `showEncounterSummarySheet(context)` ("Real-life crossings." with the three items and "Got it").

Detail: full-bleed photo with back overlay, prev/next + "N / 4", big age overlay; body: pill "You crossed paths", "A real-life crossing. A new possibility.", copy "You are both open to a connection. Give your next hello a chance.", note "Exact locations and crossing times are never shown.", primary "Like profile" (or "Like back" when `likesYou && premium`), "Pass for now", "Report or block profile" (person menu, Task 14). Unavailable (not eligible, or origin likes without premium): SubHeader "Profile unavailable", lock empty state "This profile is unavailable." / "Your current preferences and visibility settings always apply." / "Back to Discover|Likes You".

- [ ] **Step 1: Failing tests**: detail of an eligible person shows "Like profile"; detail of a blocked id shows "This profile is unavailable."; filters sheet changes are discarded on dismiss and applied on Save; after Save with `{women}` the deck no longer shows `p2`.
- [ ] **Step 2: Run** — fails. **Step 3: Implement.** **Step 4: Run** — PASS.
- [ ] **Step 5: Commit** `feat(discover): person detail, preferences sheet, encounter summary`

---

### Task 11: Likes You and Premium

**Files:**
- Create: `lib/features/likes/likes_page.dart`, `lib/features/premium/premium_page.dart`
- Test: `test/features/likes_test.dart`

Likes: `AppHeader(filters)`, "Likes You" + count pill; copy "They made the first move. Your turn." (premium) / "Someone's interested in you." (1) / "N people already like you." / empty "Your next connection starts with a like."; grid of previews (single column when 1): free → blurred photo (`ImageFiltered` sigma 18 over the portrait — labelled in code as a preview, not access control), heart lock, tag "Likes you", tap → `/likes/plus`; premium → clear photo, age, heart, tap → `/likes/people/:id`; free upsell block "rast PLUS" / "Curiosity looks good on you." / "See who's already interested. Find your next connection faster." / "See who likes you" / "You can still match for free in Discover."; premium note "Tap a profile to like them back or pass."; empty state heart "A little spark is out there." / "When someone likes you, they will appear here after your privacy delay." / "Keep exploring".

Premium: back SubHeader, brand "rast PLUS", "Less guessing. More connecting.", "See who's already into you.", three mini portraits (5, 1 with heart, 2), benefits (heart "See all your likes" / "Clear profiles. No blurred previews."; mark "Make a mutual move" / "Like them back and start a conversation."), plans `1 month $14.99 / mo · $14.99 billed monthly` and `12 months SAVE 50% $7.49 / mo · $89.88 billed annually` (year preselected), CTA "Get rast Plus" (or "Back to your likes" when premium) → `activatePreview()` + go `/likes` + toast "Premium preview unlocked. No payment was made.", note "Example prices. Demo upgrade only — no charge. In a live subscription, the selected plan would renew until cancelled.", "Restore purchases" → toast "This is a demo. There are no purchases to restore.", footer "Your privacy delay always comes first."

- [ ] **Step 1: Failing tests**: free user sees "Likes you" tags and no ages; tapping one opens Premium; "Get rast Plus" returns to Likes with ages visible; incoming count excludes a blocked `p1`.
- [ ] **Step 2–4:** fail → implement → PASS.
- [ ] **Step 5: Commit** `feat(likes): likes you grid with premium preview`

---

### Task 12: Match, Chats and Conversation

**Files:**
- Create: `lib/features/chat/match_page.dart`, `chat/chats_page.dart`, `chat/conversation_page.dart`, `chat/message_bubble.dart`
- Test: `test/features/chat_test.dart`

Match (`/matches/:personId`, dark stage): logo + close (→ `/discover`), "THAT FEELING? MUTUAL.", "It's a match." with "match." accent, two portraits (mine, theirs) with heart intersection, "You crossed paths. You both said yes. Now give that hello a go.", primary "Say hello" (chat icon) → ensure thread, `/chats/:threadId`, text "Keep exploring". Unavailable person → `/chats`.

Chats: `AppHeader(settings)`, "Chats", "Keep a good thing going.", tabs "All messages (N)" / "Unread", "YOUR CONNECTIONS" avatar strip (first 4, label "27 years old"), "MESSAGES" rows (avatar, "26 · Crossed paths", last text or "A new match. Say hello.", time, unread badge), empty "It starts with a hello." / "Your conversations will appear here.", footnote "A good conversation takes two.". Rows exclude unavailable people. Row tap → `markRead`, `/chats/:id`.

Conversation: header back, avatar, "26 · Crossed paths" / "Your next hello.", menu (person menu, Task 14); "TODAY", start card (mark bubble, "Small world. Good timing.", "You liked each other. See where a hello takes you."), bubbles (`MessageBubble({required Message m})` own = outgoing colours right, check icon; incoming left), suggestion chip "“Shall we start with a hello?”" when empty (fills composer with "Hey! How is your day going?"), composer `TextField` placeholder "Say something good..." maxLength 1000 multiline + send button; Enter sends on desktop, keyboard-aware; invalid/unavailable thread → `/chats`.

- [ ] **Step 1: Failing tests**: Chats lists 2 rows and unread filter 1; opening `t1` clears the unread badge; sending "  hi  " appends "hi" as own bubble; `/chats/nope` lands on Chats; blocking `p3` from inside the conversation lands on Chats and back does not reopen it; match page "Say hello" opens `/chats/match-p1`.
- [ ] **Step 2–4:** fail → implement → PASS.
- [ ] **Step 5: Commit** `feat(chat): match, chats list and conversation`

---

### Task 13: Profile, Location & visibility, Appearance, Notifications, Location sheet, Edit photos

**Files:**
- Create: `lib/features/profile/profile_page.dart`, `profile/location_settings_page.dart`, `profile/edit_photos_page.dart`, `profile/sheets/appearance_sheet.dart`, `profile/sheets/notifications_sheet.dart`, `profile/sheets/location_sheet.dart`
- Test: `test/features/profile_test.dart`

Profile: `AppHeader(settings)`, "Your profile", identity (avatar, "28 years old", gender label when `showGender` else "Good being you.", pill "Open to encounters" (dot) / "Visibility paused" → `/profile/location`), Plus card ("rast Plus" / "See who already likes you." or "Your Premium preview is active." → `/profile/plus`), photos row ("Your photos N/4", "Edit" → `/profile/photos`, 4 thumbs or "+"), menu rows: Dating preferences (summary) → filters sheet; Location & visibility (`"30 sec · 2 hours reveal delay"`) → `/profile/location`; Appearance ("Match your device" / "Light" / "Dark") → appearance sheet; How it works ("See how a crossing becomes a connection") → `/profile/how-it-works`; Notifications ("On"/"Off") → sheet; Safety & account ("Your boundaries matter") → `/profile/safety`; footer "rast · A LITTLE CLOSER".

Location settings: SubHeader "Location & visibility", hero "You set the pace." / "Your encounters. Your timing."; section "Location update target" `TimingGrid` of 8 intervals (`intervalLabel`), copy "Choose a target from 15 seconds to 2 minutes. Shorter intervals may use more battery; actual updates depend on your phone."; section "When should you appear?" `TimingGrid` of 8 delays (`delayChipLabel`, notes DEFAULT for 2, NO WAIT for 0, 24 HOURS for 24, min height 59), copy "Appear any time from immediately to 1 day after crossing paths. The default is 2 hours.", tip "The longer of your two delays always applies. Discover mixes the order, so it never shows a timeline of your day."; toggle "Open to encounters" / "Switch off to pause new encounters." (toasts "Encounters are back on." / "Visibility paused. Your existing chats stay open."); row "Location access" with pill Enabled/Off → location sheet.

Appearance sheet: "Your kind of light." / "Make rast feel right, day or night." / three option cards with mini previews (System, Light, Dark) / note "System follows your device. Your choice applies across the app." / "Done". Notifications sheet: "When something clicks." / "Hear about new matches and messages." / toggle "Matches & messages" "Switch off whenever you want." / tip "Notifications never include an exact encounter location or time." / "Done". Location sheet: "Let your paths cross." / copy / items Precise location, Background location / tip "Other people never see your exact location on a map." / "Enable location" or "Turn location off" (toast "Location is off. New encounters are paused."). Edit photos: `PhotoGrid` with SubHeader "Your photos", "Save photos" requires 4 ("All four photos are required."), toast "Your photos have been updated in this preview.".

- [ ] **Step 1: Failing tests**: profile shows "28 years old" and "Good being you."; appearance sheet Dark switches `Theme.of(context).brightness`; selecting 45 sec persists `rast.interval == 45`; toggling visibility off shows "Visibility paused" on Profile; removing one photo in Edit photos disables Save and (after `setPhoto(1, null)`) Discover shows "Your photos come first.".
- [ ] **Step 2–4:** fail → implement → PASS.
- [ ] **Step 5: Commit** `feat(profile): profile, location settings, appearance, notifications, edit photos`

---

### Task 14: Safety & account and all safety sheets

**Files:**
- Create: `lib/features/safety/safety_page.dart`, `safety/sheets/person_menu_sheet.dart`, `safety/sheets/report_sheet.dart`, `safety/sheets/block_confirm_sheet.dart`, `safety/sheets/remove_connection_sheet.dart`, `safety/sheets/blocked_sheet.dart`, `safety/sheets/removed_sheet.dart`, `safety/sheets/delete_account_sheet.dart`
- Modify: wire `onMenu` in `ProfileCard`, detail page and conversation header to `showPersonMenu`
- Test: `test/features/safety_test.dart`

**Interfaces:**
- Produces: `showPersonMenu(context, ref, String personId, {required String returnTo})` → title "{age} · Crossed paths", copy "Your connection. Your choice.", rows: "Remove connection" / "Delete this chat. Never match again." (only when a thread exists), "Report profile" / "Tell us about a concern", "Block profile" / "Prevent this profile from reaching you".
- Report sheet: "What would you like to report?", "Choose the reason that fits best.", 5 reason options, optional details field "Anything else to add? (optional)" (1000), checkbox checked by default "Also block and permanently remove this connection." (matched) / "Also block this profile.", "Complete report" disabled until a reason, help "Design preview: no real report is sent. Optional details are not saved."; submit → `report(id, reason)`; with block → `removePersonEverywhere(block: true)`; toasts "Report saved and profile blocked in this preview. No real report was sent." / "Report saved in this preview. No real report was sent."
- Block confirm: "Block this profile?" with matched copy "Your match and messages will be removed permanently. You will not match again, even if you later unblock this profile." or unmatched "You will no longer see each other while this profile is blocked. Manage your blocked profiles in Safety & account.", "Block profile" / "Cancel"; toast "Profile blocked. You will no longer see each other."
- Remove connection: "Remove this connection?", copy, tip "This is permanent. You can still report this person from Removed connections.", "Remove connection" / "Keep connection"; toast "Connection removed permanently. You will not match again."
- Blocked sheet: list with "Unblock" (toast "Profile unblocked. Your connection stays removed; you cannot match again." when also disconnected, else "Profile unblocked."), help "Unblocking never restores a removed connection. If you were matched before, you still cannot match again.", empty "You have not blocked any profiles."
- Removed sheet: copy "These connections are permanently closed. You will not see or match with each other again.", rows "27 · Connection removed" + "Report saved in this preview" / "No future matching" + "Report" button; empty "No removed connections. If you remove someone, that connection stays closed for good."
- Safety page: SubHeader "Safety & account", intro shield "Your boundaries matter." / "Remove a connection for good, block a profile, or report something that doesn't feel right.", rows Removed connections ("N removed · No future matching"), Blocked profiles ("N people"), Privacy information ("Your location and your data"), Terms ("For adults 18 and over"), Pause visibility ("Keep your existing conversations" → `setVisible(false)`, `/profile`, toast "Your visibility is paused."), End Premium preview (only when premium; → `/likes`, toast "Premium preview ended. Your matches and chats stay open."), Log out (toast "Signed out of the demo."), Delete account → sheet "Delete your account?" / copy / "Delete demo account" (resets intro, safety, premium, profile, threads, settings → Welcome, toast "Demo account cleared.") / "Keep account".

- [ ] **Step 1: Failing tests**: person menu on a matched person shows 3 rows, on an unmatched person 2; report with a reason and block unchecked keeps thread `t1`; report with block on `p3` removes `t1` and adds `p3` to blocked and disconnected; block unmatched `p4` then unblock → `p4` eligible again and not disconnected; remove connection then unblock keeps disconnected; "Complete report" disabled without a reason; delete account returns to Welcome and clears `rast.safety.*` keys.
- [ ] **Step 2–4:** fail → implement → PASS.
- [ ] **Step 5: Commit** `feat(safety): safety & account page, report, block, remove and lists`

---

### Task 15: Polish, verification and build

**Files:**
- Modify: `README.md` (versions, run instructions, status table), `docs/superpowers/plans/decision-log.md`
- Create: `android/app/src/main/AndroidManifest.xml` label "rast"; `ios/Runner/Info.plist` `CFBundleDisplayName` "rast", `NSPhotoLibraryUsageDescription` "rast uses your photo library so you can add your four profile photos."

- [ ] **Step 1:** Replace all placeholder pages; grep `Placeholder(` in `lib/` → none.
- [ ] **Step 2:** `flutter analyze` → "No issues found!"; `flutter test` → all pass.
- [ ] **Step 3:** `flutter build apk --debug` → `build/app/outputs/flutter-apk/app-debug.apk` exists. Record size and the exact command in the README.
- [ ] **Step 4:** Walk the app on an emulator or device if one is available (`flutter devices`); otherwise state in the README that visual parity on a device is unverified.
- [ ] **Step 5:** Update README status table (phases 1–4 → done, mock), add "Known gaps" list (no real permission prompt, blur is cosmetic, no network states, age model provisional).
- [ ] **Step 6: Commit** `docs: milestone 1 status, versions and known gaps` and push.
