import 'package:flutter_test/flutter_test.dart';
import 'package:location_lab/lab_store.dart';
import 'package:location_lab/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

LabSession session(String id, {int started = 1000, int? ended}) => LabSession(
      id: id,
      deviceId: 'dev-1',
      deviceModel: 'Pixel 9a',
      osVersion: 'Android 17',
      appVersion: '0.1.0',
      startedAtUtcMs: started,
      endedAtUtcMs: ended,
      requestedIntervalS: 30,
      requestedAccuracy: RequestedAccuracy.high,
      ntpOffsetMs: -120,
      notes: '',
    );

Sample sample(String sessionId, int seq) => Sample(
      sessionId: sessionId,
      seq: seq,
      deviceTimeUtcMs: 1000 + seq * 30000,
      fixTimeUtcMs: 900 + seq * 30000,
      lat: 41.0 + seq * 0.0001,
      lon: 29.0,
      accuracyM: 8.5,
      altitudeM: 40.0,
      speedMps: 1.2,
      headingDeg: 90.0,
      isMocked: false,
      lifecycle: Lifecycle.resumed,
      batteryPct: 80,
      batteryState: BatteryStateLabel.discharging,
    );

LabEvent event(String sessionId, int t, EventKind kind, String detail) =>
    LabEvent(sessionId: sessionId, timeUtcMs: t, kind: kind, detail: detail);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LabStore store;
  setUp(() async {
    store = await LabStore.open(inMemoryDatabasePath);
  });
  tearDown(() => store.close());

  test('round-trips a session, samples and events', () async {
    await store.insertSession(session('s1'));
    await store.insertSample(sample('s1', 1));
    await store.insertSample(sample('s1', 0));
    await store.insertSample(sample('s1', 2));
    await store.insertEvent(event('s1', 1000, EventKind.stream, 'started'));
    await store.insertEvent(event('s1', 2000, EventKind.marker, 'together'));

    final sessions = await store.sessions();
    expect(sessions.length, 1);
    expect(sessions.first.requestedAccuracy, RequestedAccuracy.high);
    expect(sessions.first.ntpOffsetMs, -120);

    final samples = await store.samples('s1');
    expect(samples.map((s) => s.seq).toList(), [0, 1, 2]);
    expect(samples.first.lifecycle, Lifecycle.resumed);
    expect(samples.first.batteryState, BatteryStateLabel.discharging);
    expect(samples.first.isMocked, isFalse);
    expect(await store.sampleCount('s1'), 3);

    final events = await store.events('s1');
    expect(events.length, 2);
    expect(events.last.kind, EventKind.marker);
    expect(events.last.detail, 'together');
  });

  test('openSession returns the unfinished session only', () async {
    await store.insertSession(session('a', started: 1000));
    await store.insertSession(session('b', started: 2000));
    await store.endSession('a', 5000);
    expect((await store.openSession())!.id, 'b');
    await store.endSession('b', 6000);
    expect(await store.openSession(), isNull);
    final all = await store.sessions();
    expect(all.firstWhere((s) => s.id == 'a').endedAtUtcMs, 5000);
  });

  test('deleteSession removes its samples and events', () async {
    await store.insertSession(session('s1'));
    await store.insertSample(sample('s1', 0));
    await store.insertEvent(event('s1', 1000, EventKind.note, 'hi'));
    await store.deleteSession('s1');
    expect(await store.sessions(), isEmpty);
    expect(await store.samples('s1'), isEmpty);
    expect(await store.events('s1'), isEmpty);
  });

  test('csv headers match the spec order', () {
    expect(Sample.csvHeader, [
      'session_id',
      'seq',
      'device_time_utc_ms',
      'fix_time_utc_ms',
      'lat',
      'lon',
      'accuracy_m',
      'altitude_m',
      'speed_mps',
      'heading_deg',
      'is_mocked',
      'lifecycle',
      'battery_pct',
      'battery_state',
    ]);
    expect(LabEvent.csvHeader, ['session_id', 'time_utc_ms', 'kind', 'detail']);
    expect(EventKind.appStart.wire, 'app_start');
    expect(sample('s1', 0).toCsvRow().length, Sample.csvHeader.length);
    expect(event('s1', 1, EventKind.marker, 'apart').toCsvRow(),
        ['s1', 1, 'marker', 'apart']);
  });
}
