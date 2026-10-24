# Location Lab (Phase 0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A throwaway Flutter app plus a Python analysis script that measure background location sampling on the owner's phones and report whether 20-metre crossings are detectable.

**Architecture:** Separate Flutter project in `labs/location_lab/` with three layers: `LabStore` (SQLite rows for sessions, samples, events), `Sampler` (wraps a `Stream<Position>` and lifecycle/battery observers, writes rows), and a two-screen Riverpod UI. Export writes CSV/JSON to the documents directory; `tools/analyze.py` turns exports into Markdown reports.

**Tech Stack:** Flutter 3.47.7, Dart 3.13, flutter_riverpod 3.4.x, geolocator 14.1.x, permission_handler 13.0.x, sqflite 2.4.x (+ sqflite_common_ffi for tests), battery_plus 7.1.x, device_info_plus 13.x, path_provider 2.1.x, share_plus 13.x, ntp 2.0.0, uuid. Python 3 standard library.

**Spec:** `docs/superpowers/specs/2026-10-24-location-lab-design.md`

## Global Constraints

- Project lives at `labs/location_lab/`; nothing under `lib/` of the product app is imported or modified.
- Android application id `app.rast.locationlab`; label "rast location lab".
- Distance filter is always 0; interval options are exactly 15, 30, 60, 120 seconds; accuracy options exactly `best`, `high`, `medium`.
- Lifecycle values: `resumed|inactive|paused|hidden|detached`. Battery states: `charging|discharging|full|unknown`. Event kinds: `lifecycle|permission|stream|error|marker|note|battery|app_start`. Marker details: `together`, `apart`.
- CSV column order is fixed by the spec and by `Sample.csvHeader` / `LabEvent.csvHeader`.
- Analysis script: Python 3 standard library only, radii {20, 30, 50} m, windows {30, 60, 120} s, outage = gap > 3 × requested interval.
- All Flutter tests run with `flutter test --timeout 90s`; Python tests with `python3 -m unittest discover -s labs/location_lab/tools -p 'test_*.py'`.

## Review Focus

1. A session left open when the process dies must be resumed on next launch and marked with an `app_start` event (Task 3 test `resumes open session and logs app_start`).
2. Battery drain must ignore charging periods, otherwise a plugged-in run reports negative drain (Task 7 test `drain ignores charging rows`).
3. Pair alignment must apply each device's NTP offset before matching, otherwise a 30 s clock skew fakes or hides a crossing (Task 8 test `alignment applies ntp offsets`).
4. Export must escape commas and quotes in `detail` notes so a free-text note cannot corrupt `events.csv` (Task 6 test `csv escapes quotes and commas`).
5. Markers pressed on only one device still define ground truth for the pair (Task 8 test `ground truth from one device only`).

---

### Task 1: Project scaffold and Android configuration

**Files:**
- Create: `labs/location_lab/` via `flutter create` (org `app.rast`, project `location_lab`, platforms android, ios)
- Modify: `labs/location_lab/pubspec.yaml`, `labs/location_lab/android/app/src/main/AndroidManifest.xml`, `labs/location_lab/ios/Runner/Info.plist`
- Create: `labs/location_lab/README.md`

**Interfaces:**
- Produces: a runnable app with all dependencies resolved; no code of its own yet.

- [ ] **Step 1: Create the project**

Run from repo root:
```bash
cd labs && ~/development/flutter/bin/flutter create --org app.rast --project-name location_lab --platforms android,ios location_lab
```
Expected: `labs/location_lab/pubspec.yaml` exists.

- [ ] **Step 2: Add dependencies**

```bash
cd labs/location_lab && ~/development/flutter/bin/flutter pub add flutter_riverpod geolocator permission_handler sqflite battery_plus device_info_plus path_provider share_plus ntp uuid intl && ~/development/flutter/bin/flutter pub add --dev sqflite_common_ffi
```
Expected: `pub get` succeeds; record resolved versions in `docs/superpowers/plans/decision-log.md` under a "Location lab dependencies" heading.

- [ ] **Step 3: Android manifest permissions and label**

Add before `<application>`:
`ACCESS_COARSE_LOCATION`, `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_LOCATION`, `POST_NOTIFICATIONS`, `WAKE_LOCK`. Set `android:label="rast location lab"`.

- [ ] **Step 4: iOS plist keys**

Add `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` (text: "The lab records your location to measure background sampling. Nothing leaves the phone."), and `UIBackgroundModes` with `location`.

- [ ] **Step 5: Verify the app builds**

Run: `cd labs/location_lab && export ANDROID_HOME=$HOME/Android/Sdk && ~/development/flutter/bin/flutter build apk --debug`
Expected: `build/app/outputs/flutter-apk/app-debug.apk` exists.

- [ ] **Step 6: README and commit**

`labs/location_lab/README.md`: what the lab is, how to build, where exports land, link to spec and PROTOCOL.md. Ensure `labs/location_lab/build/` is covered by the root `.gitignore` (add `labs/*/build/` if not).

```bash
git add labs/location_lab .gitignore docs/superpowers/plans/decision-log.md
git commit -m "feat(lab): scaffold location lab with background location permissions"
```

---

### Task 2: Models and SQLite store

**Files:**
- Create: `labs/location_lab/lib/models.dart`, `labs/location_lab/lib/lab_store.dart`
- Test: `labs/location_lab/test/lab_store_test.dart`

**Interfaces:**
- Produces:
  - `enum Lifecycle { resumed, inactive, paused, hidden, detached }`, `enum BatteryStateLabel { charging, discharging, full, unknown }`, `enum RequestedAccuracy { best, high, medium }`, `enum EventKind { lifecycle, permission, stream, error, marker, note, battery, appStart }` with `String get wire` returning the spec's snake_case names (`app_start`).
  - `class LabSession { String id; String deviceId; String deviceModel; String osVersion; String appVersion; int startedAtUtcMs; int? endedAtUtcMs; int requestedIntervalS; RequestedAccuracy requestedAccuracy; int? ntpOffsetMs; String notes; Map<String,Object?> toJson(); }`
  - `class Sample { String sessionId; int seq; int deviceTimeUtcMs; int fixTimeUtcMs; double lat; double lon; double accuracyM; double altitudeM; double speedMps; double headingDeg; bool isMocked; Lifecycle lifecycle; int batteryPct; BatteryStateLabel batteryState; static const List<String> csvHeader; List<Object?> toCsvRow(); }`
  - `class LabEvent { String sessionId; int timeUtcMs; EventKind kind; String detail; static const List<String> csvHeader; List<Object?> toCsvRow(); }`
  - `class LabStore { LabStore(Database db); static Future<LabStore> open(String path); Future<void> insertSession(LabSession); Future<void> endSession(String id, int endedAtUtcMs); Future<LabSession?> openSession(); Future<List<LabSession>> sessions(); Future<void> insertSample(Sample); Future<void> insertEvent(LabEvent); Future<List<Sample>> samples(String sessionId); Future<List<LabEvent>> events(String sessionId); Future<int> sampleCount(String sessionId); Future<void> deleteSession(String id); }`
  - `openSession()` returns the single session with `ended_at_utc_ms IS NULL`, or null.

- [ ] **Step 1: Write failing tests**

```dart
// test/lab_store_test.dart — setUpAll: sqfliteFfiInit(); databaseFactory = databaseFactoryFfi;
// each test: final store = await LabStore.open(inMemoryDatabasePath);
test('round-trips a session, samples and events', ...); // insert 1 session, 3 samples, 2 events; expect sessions().length 1, samples(id).length 3 ordered by seq, events(id).length 2
test('openSession returns the unfinished session only', ...); // two sessions, end one; expect openSession()!.id == the other; end it; expect null
test('deleteSession removes its samples and events', ...);
test('csv headers match the spec order', () {
  expect(Sample.csvHeader, ['session_id','seq','device_time_utc_ms','fix_time_utc_ms','lat','lon','accuracy_m','altitude_m','speed_mps','heading_deg','is_mocked','lifecycle','battery_pct','battery_state']);
  expect(LabEvent.csvHeader, ['session_id','time_utc_ms','kind','detail']);
  expect(EventKind.appStart.wire, 'app_start');
});
```

- [ ] **Step 2: Run tests, expect compile failure**

Run: `cd labs/location_lab && ~/development/flutter/bin/flutter test --timeout 90s test/lab_store_test.dart`

- [ ] **Step 3: Implement `models.dart` and `lab_store.dart`**

Three tables `session`, `sample`, `event` with the spec's columns; `sample` has a composite primary key `(session_id, seq)`; foreign keys deleted manually in `deleteSession`.

- [ ] **Step 4: Run tests, expect PASS**

- [ ] **Step 5: Commit**

```bash
git add labs/location_lab/lib/models.dart labs/location_lab/lib/lab_store.dart labs/location_lab/test/lab_store_test.dart
git commit -m "feat(lab): session, sample and event models with sqlite store"
```

---

### Task 3: Sampler

**Files:**
- Create: `labs/location_lab/lib/sampler.dart`
- Test: `labs/location_lab/test/sampler_test.dart`

**Interfaces:**
- Consumes: `LabStore`, models from Task 2.
- Produces:
  - `typedef PositionStreamFactory = Stream<Position> Function(int intervalS, RequestedAccuracy accuracy);`
  - `typedef BatteryReader = Future<(int pct, BatteryStateLabel state)> Function();`
  - `class SamplerConfig { int intervalS; RequestedAccuracy accuracy; }`
  - `class SamplerStatus { bool running; String? sessionId; int sampleCount; int? lastFixUtcMs; double? lastAccuracyM; Lifecycle lifecycle; int? batteryPct; }`
  - `class Sampler extends ChangeNotifier { Sampler({required LabStore store, required PositionStreamFactory positions, required BatteryReader battery, required DateTime Function() now, required Future<LabSession> Function(SamplerConfig) newSession}); SamplerStatus get status; Future<void> start(SamplerConfig); Future<void> stop(); Future<bool> resumeIfOpen(); void onLifecycle(Lifecycle); Future<void> marker(String detail); Future<void> note(String text); Future<void> logEvent(EventKind kind, String detail); }`
  - `resumeIfOpen()`: if `store.openSession()` is non-null, write an `app_start` event, restart the stream with that session's interval and accuracy, return true.
  - Every received `Position` becomes one `Sample` with `seq` incrementing from the stored count, `lifecycle` from the last `onLifecycle`, battery from `battery()` (read at most once every 60 s, cached between). Stream errors become `error` events; stream start and stop become `stream` events with detail `started`/`stopped`. Lifecycle changes are written as `lifecycle` events with the enum name.

- [ ] **Step 1: Write failing tests**

Use a `StreamController<Position>` as the factory, a fixed clock, a fake battery returning `(80, discharging)`.

```dart
test('start creates a session and writes one sample per position', ...); // add 3 positions; expect sampleCount 3, seq 0..2, battery_pct 80
test('stop ends the session and logs stream stopped', ...);
test('resumes open session and logs app_start', ...); // insert an unfinished session directly into the store; resumeIfOpen() == true; events contain kind appStart; new positions land in that session with seq continuing
test('resumeIfOpen is false with no open session', ...);
test('lifecycle change is logged and stamped on later samples', ...); // onLifecycle(paused) then a position → sample.lifecycle == paused
test('marker writes a marker event', ...); // marker('together') → event kind marker detail together
```

- [ ] **Step 2: Run tests, expect failure**

- [ ] **Step 3: Implement `sampler.dart`**

Hold the `StreamSubscription`; `notifyListeners()` after each sample and event.

- [ ] **Step 4: Run tests, expect PASS**

- [ ] **Step 5: Commit** `feat(lab): sampler writes positions, lifecycle and battery to the store`

---

### Task 4: Platform wiring and permissions

**Files:**
- Create: `labs/location_lab/lib/platform.dart`, `labs/location_lab/lib/permissions.dart`, `labs/location_lab/lib/providers.dart`
- Test: `labs/location_lab/test/permissions_test.dart`

**Interfaces:**
- Produces:
  - `Stream<Position> geolocatorStream(int intervalS, RequestedAccuracy accuracy)` in `platform.dart`: `AndroidSettings(accuracy: mapped, distanceFilter: 0, intervalDuration: Duration(seconds: intervalS), foregroundNotificationConfig: ForegroundNotificationConfig(notificationTitle: 'rast location lab', notificationText: 'Recording location samples', enableWakeLock: true, setOngoing: true))` on Android; `AppleSettings(accuracy: mapped, activityType: ActivityType.other, distanceFilter: 0, pauseLocationUpdatesAutomatically: false, showBackgroundLocationIndicator: true, allowBackgroundLocationUpdates: true)` on iOS. Mapping: best→`LocationAccuracy.best`, high→`high`, medium→`medium`.
  - `Future<(int, BatteryStateLabel)> readBattery()` using battery_plus.
  - `Future<LabSession> buildSession(SamplerConfig, {required String deviceId})` in `platform.dart`: fills model, OS version, app version (from `PackageInfo` is not a dep; use a constant `labVersion = '0.1.0'`), and `ntpOffsetMs` via `NTP.getNtpOffset()` with a 3 s timeout, null on failure.
  - `enum PermissionItem { fineLocation, backgroundLocation, notifications }`, `class PermissionSnapshot { Map<PermissionItem, bool> granted; }`, `abstract class PermissionGateway { Future<bool> isGranted(PermissionItem); Future<bool> request(PermissionItem); }`, `class PermissionFlow { PermissionFlow(PermissionGateway); Future<PermissionSnapshot> snapshot(); Future<PermissionItem?> requestNextMissing(); }` where `requestNextMissing` requests in the order fine → background → notifications and returns the item it requested, or null when all are granted.
  - Riverpod providers in `providers.dart`: `labStoreProvider` (FutureProvider opening `<documents>/lab.db`), `deviceIdProvider` (uuid persisted in a file `<documents>/device_id`), `samplerProvider` (ChangeNotifierProvider wiring real factories), `permissionFlowProvider`.

- [ ] **Step 1: Write failing tests for `PermissionFlow`** with a fake gateway

```dart
test('requests fine before background before notifications', ...);
test('returns null when everything is granted', ...);
```

- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement `permissions.dart`, `platform.dart`, `providers.dart`**
- [ ] **Step 4: Run tests, expect PASS; `flutter analyze` clean**
- [ ] **Step 5: Commit** `feat(lab): geolocator stream, battery, ntp and permission flow`

---

### Task 5: Home and Sessions screens

**Files:**
- Create: `labs/location_lab/lib/main.dart`, `labs/location_lab/lib/home_page.dart`, `labs/location_lab/lib/sessions_page.dart`
- Test: `labs/location_lab/test/home_page_test.dart`

**Interfaces:**
- Consumes: `Sampler`, `PermissionFlow`, `LabStore`, providers from Task 4.
- Produces: `class LabApp extends StatelessWidget` (MaterialApp, routes `/` → `HomePage`, `/sessions` → `SessionsPage`); `main()` wraps in `ProviderScope`, adds a `WidgetsBindingObserver` that forwards `AppLifecycleState` to `sampler.onLifecycle`, and calls `sampler.resumeIfOpen()` after the store opens.

- [ ] **Step 1: Write failing widget tests** overriding `samplerProvider` with a `Sampler` built on fakes and `permissionFlowProvider` with an all-granted fake

```dart
testWidgets('shows interval and accuracy chips and a Start button', ...); // finds '15 s','30 s','60 s','120 s','Best','High','Medium','Start'
testWidgets('Start becomes Stop and live count updates', ...); // tap Start; push a position; expect text 'Samples: 1' and 'Stop'
testWidgets('Together marker logs an event', ...); // tap 'Together'; expect event feed shows 'marker: together'
testWidgets('missing permission shows Fix button', ...); // fake with background missing → finds 'Fix'
```

- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement the screens** per spec: permission row, chips, Start/Stop, live panel (`Samples: n`, `Last fix: n s ago`, `Accuracy: n m`, `State: resumed`, `Battery: n%`), marker buttons, note field with "Add note", event feed (last 20), app bar action to `/sessions`. Sessions page: `ListTile` per session with start time, duration, interval, sample count; trailing menu Export / Delete (Export wired in Task 6; stub shows a SnackBar until then).
- [ ] **Step 4: Run tests, expect PASS; `flutter analyze` clean**
- [ ] **Step 5: Commit** `feat(lab): home and sessions screens`

---

### Task 6: Export

**Files:**
- Create: `labs/location_lab/lib/export.dart`
- Modify: `labs/location_lab/lib/sessions_page.dart` (wire Export)
- Test: `labs/location_lab/test/export_test.dart`

**Interfaces:**
- Produces: `String toCsv(List<String> header, Iterable<List<Object?>> rows)` (RFC 4180: fields containing `,`, `"` or newline are quoted, quotes doubled; `\n` line endings; booleans as `true`/`false`; enums as their wire name); `Future<List<File>> writeExport(LabStore store, LabSession session, Directory root)` writing `root/exports/<session_id>/session.json`, `samples.csv`, `events.csv` and returning the three files; `Future<void> shareExport(List<File>)` using `Share.shareXFiles`.

- [ ] **Step 1: Write failing tests**

```dart
test('csv escapes quotes and commas', () { expect(toCsv(['a','b'], [['x,y', 'he said "hi"']]), 'a,b\n"x,y","he said ""hi"""\n'); });
test('writeExport produces three files with headers and one row per record', ...); // temp dir; 2 samples, 1 event → samples.csv has 3 lines
test('session.json round-trips through jsonDecode', ...);
```

- [ ] **Step 2: Run, expect failure**
- [ ] **Step 3: Implement `export.dart`, wire the Sessions page Export action to write then share**
- [ ] **Step 4: Run tests, expect PASS**
- [ ] **Step 5: Commit** `feat(lab): csv/json export and share sheet`

---

### Task 7: Analysis script, single device

**Files:**
- Create: `labs/location_lab/tools/analyze.py`, `labs/location_lab/tools/test_analyze_single.py`

**Interfaces:**
- Produces (module `analyze`):
  - `load_export(path) -> Export` with `Export(session: dict, samples: list[dict], events: list[dict])`, numeric columns parsed to int/float, `is_mocked` to bool.
  - `intervals(samples) -> list[float]` seconds between consecutive `device_time_utc_ms`.
  - `percentile(values, p) -> float` (nearest-rank).
  - `outages(samples, interval_s) -> list[Outage]` with `Outage(start_utc_ms, length_s, lifecycle_before)` for gaps `> 3 * interval_s`.
  - `sample_ages(samples) -> list[float]` seconds `(device_time - fix_time)`.
  - `battery_drain_per_hour(samples) -> float | None` least-squares slope of `battery_pct` against hours over rows with `battery_state == 'discharging'`, negated so drain is positive; None with fewer than 2 rows or under 10 minutes span.
  - `single_report(export) -> str` Markdown with the spec's sections.
  - CLI: `python3 analyze.py single <dir>` prints `single_report`.

- [ ] **Step 1: Write failing unittest cases** with small in-memory sample lists (helper `mk(t_ms, lat, lon, acc, pct=80, state='discharging', lifecycle='resumed', fix=None)`)

```python
def test_intervals_and_percentiles(self): # samples at 0,30,60,150 s → intervals [30,30,90]; percentile(...,50)==30; percentile(...,100)==90
def test_outages_use_three_times_interval(self): # interval 30: gap 90 is not an outage, gap 91 is; lifecycle_before taken from the sample before the gap
def test_sample_ages(self): # fix 2 s before device time → 2.0
def test_drain_ignores_charging_rows(self): # discharging 100→90 over 1 h plus charging rows rising → 10.0
def test_drain_none_for_short_span(self): # 5 minutes → None
def test_single_report_mentions_requested_interval(self): # '30 s' in report
```

- [ ] **Step 2: Run, expect ImportError**: `python3 -m unittest discover -s labs/location_lab/tools -p 'test_*.py'`
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run tests, expect OK**
- [ ] **Step 5: Commit** `feat(lab): single-device analysis report`

---

### Task 8: Analysis script, pair mode

**Files:**
- Modify: `labs/location_lab/tools/analyze.py`
- Create: `labs/location_lab/tools/test_analyze_pair.py`

**Interfaces:**
- Produces:
  - `haversine_m(lat1, lon1, lat2, lon2) -> float`.
  - `corrected_time(sample, session) -> int` = `device_time_utc_ms + (session['ntp_offset_ms'] or 0)`.
  - `align(a: Export, b: Export, window_s: int) -> list[Pairing]` with `Pairing(t_utc_ms, distance_m, optimistic_m, acc_a, acc_b)`: for each sample of A, the nearest-in-corrected-time sample of B within `window_s`; `optimistic_m = max(0, distance - (acc_a + acc_b))`.
  - `detections(pairings, radius_m) -> list[Interval]` with `Interval(start_utc_ms, end_utc_ms)`: consecutive pairings with `distance_m <= radius_m` merged into one interval.
  - `ground_truth(a: Export, b: Export) -> list[Interval]` from `marker` events on either device: `together` opens, `apart` closes; an unclosed interval ends at the later session end.
  - `score(detections, truth) -> Score(recall: float, false_detections: int, min_distance_per_truth: list[float | None])`.
  - `pair_report(a, b) -> str` Markdown with one table over radii {20, 30, 50} × windows {30, 60, 120}.
  - CLI: `python3 analyze.py pair <dirA> <dirB>`.

- [ ] **Step 1: Write failing tests**

```python
def test_haversine_known_distance(self): # (41.0082,28.9784)->(41.0084,28.9784) ≈ 22.2 m within 0.5
def test_alignment_applies_ntp_offsets(self): # B's clock is 30 s ahead, ntp_offset_ms -30000; samples that are simultaneous in true time pair up; without offset they would not within window 10
def test_detections_merge_consecutive(self): # distances [50,10,10,50,10] radius 20 → two intervals
def test_ground_truth_from_one_device_only(self): # only A has together/apart → one interval
def test_score_recall_and_false(self): # truth [100,200]; detections [120,130] and [500,510] → recall 1.0, false 1
def test_pair_report_has_nine_rows(self): # 3 radii × 3 windows
```

- [ ] **Step 2: Run, expect failures**
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run tests, expect OK**
- [ ] **Step 5: Commit** `feat(lab): pair analysis with radius and window sensitivity`

---

### Task 9: Protocol document

**Files:**
- Create: `labs/location_lab/PROTOCOL.md`

- [ ] **Step 1: Write the protocol** from the spec's run list: for each run, phones, duration, settings (interval, accuracy), what the tester does, what to press and when (markers), what to export and how to name it, which `analyze.py` command to run. Add a results table template per device and a "decision" section the owner fills in and copies into the decision log.
- [ ] **Step 2: Commit** `docs(lab): Phase 0 test protocol`

---

### Task 10: First device run

**Files:**
- Modify: `docs/superpowers/plans/decision-log.md`

- [ ] **Step 1: Build and install** on the Pixel 9a: `flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk`.
- [ ] **Step 2: Grant permissions in the app** (fine, "Allow all the time", notifications) and start a 30 s / high session; lock the screen for 10 minutes; unlock; stop.
- [ ] **Step 3: Pull the export**: `adb shell run-as app.rast.locationlab ls files/exports` is not available in release; in debug use `adb exec-out run-as app.rast.locationlab tar c app_flutter/exports | tar x -C /tmp/lab`. If `run-as` is refused, use the in-app share to a local target.
- [ ] **Step 4: Run** `python3 labs/location_lab/tools/analyze.py single <dir>` and paste the report into the decision log under "2026-10-24 — Phase 0 first run (Pixel 9a)".
- [ ] **Step 5: Commit** `docs: Phase 0 first single-device run`
