import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location_lab/lab_store.dart';
import 'package:location_lab/models.dart';
import 'package:location_lab/sampler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Position pos(int tMs, {double lat = 41.0, double acc = 7.0}) => Position(
      latitude: lat,
      longitude: 29.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: true),
      accuracy: acc,
      altitude: 10,
      altitudeAccuracy: 1,
      heading: 0,
      headingAccuracy: 1,
      speed: 0,
      speedAccuracy: 1,
      isMocked: false,
    );

class Harness {
  Harness(this.store) {
    sampler = Sampler(
      store: store,
      positions: (interval, accuracy) {
        requested.add((interval, accuracy));
        controller = StreamController<Position>();
        return controller.stream;
      },
      battery: () async => (80, BatteryStateLabel.discharging),
      now: () => DateTime.fromMillisecondsSinceEpoch(nowMs, isUtc: true),
      newSession: (config) async => LabSession(
        id: 'sess-${++created}',
        deviceId: 'dev',
        deviceModel: 'Test',
        osVersion: 'T1',
        appVersion: '0.1.0',
        startedAtUtcMs: nowMs,
        requestedIntervalS: config.intervalS,
        requestedAccuracy: config.accuracy,
      ),
    );
  }

  final LabStore store;
  late Sampler sampler;
  late StreamController<Position> controller;
  final requested = <(int, RequestedAccuracy)>[];
  int nowMs = 1000000;
  int created = 0;

  Future<void> emit(Position p) async {
    controller.add(p);
    await Future<void>.delayed(Duration.zero);
    await sampler.flush();
  }
}

/// Store whose event writes fail on demand; everything else is delegated.
class FailingEventsStore implements LabStore {
  FailingEventsStore(this.inner);
  final LabStore inner;
  bool failEvents = false;

  @override
  Future<void> insertEvent(LabEvent e) =>
      failEvents ? Future.error(StateError('disk full')) : inner.insertEvent(e);
  @override
  Future<void> close() => inner.close();
  @override
  Future<void> insertSession(LabSession s) => inner.insertSession(s);
  @override
  Future<void> endSession(String id, int endedAtUtcMs) => inner.endSession(id, endedAtUtcMs);
  @override
  Future<LabSession?> openSession() => inner.openSession();
  @override
  Future<List<LabSession>> sessions() => inner.sessions();
  @override
  Future<void> insertSample(Sample s) => inner.insertSample(s);
  @override
  Future<List<Sample>> samples(String sessionId) => inner.samples(sessionId);
  @override
  Future<List<LabEvent>> events(String sessionId) => inner.events(sessionId);
  @override
  Future<int> sampleCount(String sessionId) => inner.sampleCount(sessionId);
  @override
  Future<int> nextSeq(String sessionId) => inner.nextSeq(sessionId);
  @override
  Future<void> deleteSession(String id) => inner.deleteSession(id);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late LabStore store;
  late Harness h;
  setUp(() async {
    store = await LabStore.open(inMemoryDatabasePath);
    h = Harness(store);
  });
  tearDown(() => store.close());

  const config = SamplerConfig(intervalS: 30, accuracy: RequestedAccuracy.high);

  test('start creates a session and writes one sample per position', () async {
    await h.sampler.start(config);
    expect(h.requested, [(30, RequestedAccuracy.high)]);
    await h.emit(pos(1000100));
    await h.emit(pos(1000200));
    await h.emit(pos(1000300));

    final id = h.sampler.status.sessionId!;
    final samples = await store.samples(id);
    expect(samples.map((s) => s.seq).toList(), [0, 1, 2]);
    expect(samples.first.batteryPct, 80);
    expect(samples.first.fixTimeUtcMs, 1000100);
    expect(h.sampler.status.sampleCount, 3);
    expect(h.sampler.status.lastAccuracyM, 7.0);
    expect(h.sampler.status.running, isTrue);
  });

  test('stop ends the session and logs stream stopped', () async {
    await h.sampler.start(config);
    final id = h.sampler.status.sessionId!;
    h.nowMs = 2000000;
    await h.sampler.stop();
    expect(h.sampler.status.running, isFalse);
    expect(await store.openSession(), isNull);
    final session = (await store.sessions()).single;
    expect(session.endedAtUtcMs, 2000000);
    final kinds = (await store.events(id)).map((e) => '${e.kind.wire}:${e.detail}');
    expect(kinds, containsAll(['stream:started', 'stream:stopped']));
  });

  test('resumes open session and logs app_start', () async {
    await store.insertSession(const LabSession(
      id: 'open-1',
      deviceId: 'dev',
      deviceModel: 'Test',
      osVersion: 'T1',
      appVersion: '0.1.0',
      startedAtUtcMs: 500000,
      requestedIntervalS: 60,
      requestedAccuracy: RequestedAccuracy.best,
    ));
    await store.insertSample(Sample(
      sessionId: 'open-1',
      seq: 0,
      deviceTimeUtcMs: 500100,
      fixTimeUtcMs: 500100,
      lat: 41,
      lon: 29,
      accuracyM: 5,
      altitudeM: 0,
      speedMps: 0,
      headingDeg: 0,
      isMocked: false,
      lifecycle: Lifecycle.resumed,
      batteryPct: 90,
      batteryState: BatteryStateLabel.discharging,
    ));

    expect(await h.sampler.resumeIfOpen(), isTrue);
    expect(h.requested, [(60, RequestedAccuracy.best)]);
    expect(h.sampler.status.sessionId, 'open-1');
    expect(h.sampler.status.config?.intervalS, 60);
    expect(h.sampler.status.config?.accuracy, RequestedAccuracy.best);
    await h.emit(pos(1000100));

    final events = await store.events('open-1');
    expect(events.map((e) => e.kind), contains(EventKind.appStart));
    final samples = await store.samples('open-1');
    expect(samples.map((s) => s.seq).toList(), [0, 1]);
  });

  test('resumeIfOpen is false with no open session', () async {
    expect(await h.sampler.resumeIfOpen(), isFalse);
    expect(h.sampler.status.running, isFalse);
  });

  test('lifecycle change is logged and stamped on later samples', () async {
    await h.sampler.start(config);
    h.sampler.onLifecycle(Lifecycle.paused);
    await h.sampler.flush();
    await h.emit(pos(1000100));
    final id = h.sampler.status.sessionId!;
    final samples = await store.samples(id);
    expect(samples.single.lifecycle, Lifecycle.paused);
    final events = await store.events(id);
    expect(events.any((e) => e.kind == EventKind.lifecycle && e.detail == 'paused'), isTrue);
    expect(h.sampler.status.lifecycle, Lifecycle.paused);
  });

  test('marker writes a marker event', () async {
    await h.sampler.start(config);
    await h.sampler.marker('together');
    await h.sampler.note('passing by the kiosk');
    final id = h.sampler.status.sessionId!;
    final events = await store.events(id);
    expect(events.any((e) => e.kind == EventKind.marker && e.detail == 'together'), isTrue);
    expect(events.any((e) => e.kind == EventKind.note && e.detail == 'passing by the kiosk'), isTrue);
  });

  test('a second start while the first is still starting is ignored', () async {
    final gate = Completer<void>();
    final slow = Sampler(
      store: store,
      positions: (_, _) => h.controller.stream,
      battery: () async => (80, BatteryStateLabel.discharging),
      now: () => DateTime.fromMillisecondsSinceEpoch(h.nowMs, isUtc: true),
      newSession: (config) async {
        await gate.future;
        return LabSession(
          id: 'slow-${++h.created}',
          deviceId: 'dev',
          deviceModel: 'Test',
          osVersion: 'T1',
          appVersion: '0.1.0',
          startedAtUtcMs: h.nowMs,
          requestedIntervalS: config.intervalS,
          requestedAccuracy: config.accuracy,
        );
      },
    );
    h.controller = StreamController<Position>();
    final first = slow.start(config);
    expect(slow.status.busy, isTrue);
    final second = slow.start(config);
    gate.complete();
    await Future.wait([first, second]);
    expect((await store.sessions()).length, 1);
    expect(slow.status.busy, isFalse);
    expect(slow.status.running, isTrue);
  });

  test('stream error is surfaced on status', () async {
    await h.sampler.start(config);
    h.controller.addError(StateError('gps off'));
    await Future<void>.delayed(Duration.zero);
    await h.sampler.flush();
    expect(h.sampler.status.lastStreamError, contains('gps off'));
  });

  test('resume continues after the highest stored seq, not the row count', () async {
    await store.insertSession(const LabSession(
      id: 'gap-1',
      deviceId: 'dev',
      deviceModel: 'Test',
      osVersion: 'T1',
      appVersion: '0.1.0',
      startedAtUtcMs: 500000,
      requestedIntervalS: 60,
      requestedAccuracy: RequestedAccuracy.best,
    ));
    // seq 0 is missing (a failed insert); only seq 1 exists.
    await store.insertSample(Sample(
      sessionId: 'gap-1',
      seq: 1,
      deviceTimeUtcMs: 500100,
      fixTimeUtcMs: 500100,
      lat: 41,
      lon: 29,
      accuracyM: 5,
      altitudeM: 0,
      speedMps: 0,
      headingDeg: 0,
      isMocked: false,
      lifecycle: Lifecycle.resumed,
      batteryPct: 90,
      batteryState: BatteryStateLabel.discharging,
    ));
    expect(await h.sampler.resumeIfOpen(), isTrue);
    await h.emit(pos(1000100));
    expect((await store.samples('gap-1')).map((s) => s.seq).toList(), [1, 2]);
    expect(h.sampler.status.lastWriteError, isNull);
  });

  test('stop ends the session even when the stopped event cannot be written', () async {
    final failing = FailingEventsStore(store);
    final s = Sampler(
      store: failing,
      positions: (_, _) => h.controller.stream,
      battery: () async => (80, BatteryStateLabel.discharging),
      now: () => DateTime.fromMillisecondsSinceEpoch(h.nowMs, isUtc: true),
      newSession: (config) async => LabSession(
        id: 'fail-1',
        deviceId: 'dev',
        deviceModel: 'Test',
        osVersion: 'T1',
        appVersion: '0.1.0',
        startedAtUtcMs: h.nowMs,
        requestedIntervalS: config.intervalS,
        requestedAccuracy: config.accuracy,
      ),
    );
    h.controller = StreamController<Position>();
    await s.start(config);
    failing.failEvents = true;
    await s.marker('together'); // must not throw
    await s.stop();
    expect(await store.openSession(), isNull);
    expect(s.status.lastWriteError, contains('disk full'));
  });

  test('stream error is logged and sampling continues', () async {
    await h.sampler.start(config);
    h.controller.addError(StateError('gps off'));
    await Future<void>.delayed(Duration.zero);
    await h.sampler.flush();
    final id = h.sampler.status.sessionId!;
    final events = await store.events(id);
    expect(events.any((e) => e.kind == EventKind.error && e.detail.contains('gps off')), isTrue);
    expect(h.sampler.status.running, isTrue);
  });
}
