import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'lab_store.dart';
import 'models.dart';

typedef PositionStreamFactory = Stream<Position> Function(
    int intervalS, RequestedAccuracy accuracy);

typedef BatteryReader = Future<(int pct, BatteryStateLabel state)> Function();

class SamplerConfig {
  const SamplerConfig({required this.intervalS, required this.accuracy});

  final int intervalS;
  final RequestedAccuracy accuracy;
}

class SamplerStatus {
  const SamplerStatus({
    this.running = false,
    this.sessionId,
    this.sampleCount = 0,
    this.lastFixUtcMs,
    this.lastAccuracyM,
    this.lifecycle = Lifecycle.resumed,
    this.batteryPct,
  });

  final bool running;
  final String? sessionId;
  final int sampleCount;
  final int? lastFixUtcMs;
  final double? lastAccuracyM;
  final Lifecycle lifecycle;
  final int? batteryPct;

  SamplerStatus copyWith({
    bool? running,
    String? sessionId,
    bool clearSession = false,
    int? sampleCount,
    int? lastFixUtcMs,
    double? lastAccuracyM,
    Lifecycle? lifecycle,
    int? batteryPct,
  }) =>
      SamplerStatus(
        running: running ?? this.running,
        sessionId: clearSession ? null : (sessionId ?? this.sessionId),
        sampleCount: sampleCount ?? this.sampleCount,
        lastFixUtcMs: lastFixUtcMs ?? this.lastFixUtcMs,
        lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
        lifecycle: lifecycle ?? this.lifecycle,
        batteryPct: batteryPct ?? this.batteryPct,
      );
}

/// Turns a position stream into stored samples and events for one session.
class Sampler extends ChangeNotifier {
  Sampler({
    required LabStore store,
    required PositionStreamFactory positions,
    required BatteryReader battery,
    required DateTime Function() now,
    required Future<LabSession> Function(SamplerConfig) newSession,
  })  : _store = store, // ignore: prefer_initializing_formals
        _positions = positions, // ignore: prefer_initializing_formals
        _battery = battery, // ignore: prefer_initializing_formals
        _now = now, // ignore: prefer_initializing_formals
        _newSession = newSession; // ignore: prefer_initializing_formals

  static const _batteryCacheWindow = Duration(seconds: 60);

  final LabStore _store;
  final PositionStreamFactory _positions;
  final BatteryReader _battery;
  final DateTime Function() _now;
  final Future<LabSession> Function(SamplerConfig) _newSession;

  SamplerStatus _status = const SamplerStatus();
  SamplerStatus get status => _status;

  StreamSubscription<Position>? _sub;
  int _nextSeq = 0;
  (int, BatteryStateLabel)? _batteryCache;
  DateTime? _batteryReadAt;
  Future<void> _writes = Future.value();

  int get _nowMs => _now().millisecondsSinceEpoch;

  /// Completes when every queued sample and event write has landed.
  Future<void> flush() => _writes;

  Future<void> start(SamplerConfig config) async {
    if (_status.running) return;
    final session = await _newSession(config);
    await _store.insertSession(session);
    _nextSeq = 0;
    _status = SamplerStatus(sessionId: session.id, lifecycle: _status.lifecycle);
    await _listen(session.requestedIntervalS, session.requestedAccuracy);
  }

  Future<bool> resumeIfOpen() async {
    if (_status.running) return true;
    final session = await _store.openSession();
    if (session == null) return false;
    _nextSeq = await _store.sampleCount(session.id);
    _status = SamplerStatus(
      sessionId: session.id,
      sampleCount: _nextSeq,
      lifecycle: _status.lifecycle,
    );
    await _write(LabEvent(
      sessionId: session.id,
      timeUtcMs: _nowMs,
      kind: EventKind.appStart,
      detail: 'resumed open session',
    ));
    await _listen(session.requestedIntervalS, session.requestedAccuracy);
    return true;
  }

  Future<void> _listen(int intervalS, RequestedAccuracy accuracy) async {
    _sub = _positions(intervalS, accuracy).listen(
      _onPosition,
      onError: (Object e) => logEvent(EventKind.error, e.toString()),
      cancelOnError: false,
    );
    _status = _status.copyWith(running: true);
    await logEvent(EventKind.stream, 'started');
  }

  Future<void> stop() async {
    if (!_status.running) return;
    await _sub?.cancel();
    _sub = null;
    await _writes;
    await logEvent(EventKind.stream, 'stopped');
    final id = _status.sessionId;
    if (id != null) await _store.endSession(id, _nowMs);
    _status = _status.copyWith(running: false, clearSession: true);
    notifyListeners();
  }

  void onLifecycle(Lifecycle state) {
    final changed = state != _status.lifecycle;
    _status = _status.copyWith(lifecycle: state);
    if (changed && _status.sessionId != null) {
      logEvent(EventKind.lifecycle, state.name);
    }
    notifyListeners();
  }

  Future<void> marker(String detail) => logEvent(EventKind.marker, detail);

  Future<void> note(String text) => logEvent(EventKind.note, text);

  Future<void> logEvent(EventKind kind, String detail) async {
    final id = _status.sessionId;
    if (id == null) return;
    await _write(LabEvent(sessionId: id, timeUtcMs: _nowMs, kind: kind, detail: detail));
  }

  void _onPosition(Position p) {
    _enqueue(() async {
      final id = _status.sessionId;
      if (id == null) return;
      final (pct, state) = await _readBattery();
      final seq = _nextSeq++;
      await _store.insertSample(Sample(
        sessionId: id,
        seq: seq,
        deviceTimeUtcMs: _nowMs,
        fixTimeUtcMs: p.timestamp.toUtc().millisecondsSinceEpoch,
        lat: p.latitude,
        lon: p.longitude,
        accuracyM: p.accuracy,
        altitudeM: p.altitude,
        speedMps: p.speed,
        headingDeg: p.heading,
        isMocked: p.isMocked,
        lifecycle: _status.lifecycle,
        batteryPct: pct,
        batteryState: state,
      ));
      _status = _status.copyWith(
        sampleCount: seq + 1,
        lastFixUtcMs: p.timestamp.toUtc().millisecondsSinceEpoch,
        lastAccuracyM: p.accuracy,
        batteryPct: pct,
      );
      notifyListeners();
    });
  }

  Future<(int, BatteryStateLabel)> _readBattery() async {
    final now = _now();
    final cached = _batteryCache;
    final at = _batteryReadAt;
    if (cached != null && at != null && now.difference(at) < _batteryCacheWindow) {
      return cached;
    }
    try {
      _batteryCache = await _battery();
    } catch (_) {
      _batteryCache = (-1, BatteryStateLabel.unknown);
    }
    _batteryReadAt = now;
    return _batteryCache!;
  }

  /// Serialises writes so seq numbers and event order stay monotonic.
  /// Returns the future of this job only, so a job may log an event without
  /// waiting on itself.
  Future<void> _enqueue(Future<void> Function() job) {
    final next = _writes.then((_) => job());
    _writes = next.catchError((_) {});
    return next;
  }

  Future<void> _write(LabEvent e) =>
      _enqueue(() => _store.insertEvent(e)).then((_) => notifyListeners());

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
