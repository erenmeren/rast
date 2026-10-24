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
    this.eventRevision = 0,
    this.lastWriteError,
    this.lastStreamError,
    this.busy = false,
  });

  final bool running;
  final String? sessionId;
  final int sampleCount;
  final int? lastFixUtcMs;
  final double? lastAccuracyM;
  final Lifecycle lifecycle;
  final int? batteryPct;

  /// Increments on every stored event; the UI uses it to refresh the feed.
  final int eventRevision;

  /// Last storage failure, shown on the home screen so dropped rows are visible.
  final String? lastWriteError;

  /// Last error from the position stream (permission revoked, GPS off, ...).
  final String? lastStreamError;

  /// True while start, stop or resume is in progress; the UI disables actions.
  final bool busy;

  SamplerStatus copyWith({
    bool? running,
    String? sessionId,
    bool clearSession = false,
    int? sampleCount,
    int? lastFixUtcMs,
    double? lastAccuracyM,
    Lifecycle? lifecycle,
    int? batteryPct,
    int? eventRevision,
    String? lastWriteError,
    String? lastStreamError,
    bool clearStreamError = false,
    bool? busy,
  }) =>
      SamplerStatus(
        running: running ?? this.running,
        sessionId: clearSession ? null : (sessionId ?? this.sessionId),
        sampleCount: sampleCount ?? this.sampleCount,
        lastFixUtcMs: lastFixUtcMs ?? this.lastFixUtcMs,
        lastAccuracyM: lastAccuracyM ?? this.lastAccuracyM,
        lifecycle: lifecycle ?? this.lifecycle,
        batteryPct: batteryPct ?? this.batteryPct,
        eventRevision: eventRevision ?? this.eventRevision,
        lastWriteError: lastWriteError ?? this.lastWriteError,
        lastStreamError: clearStreamError ? null : (lastStreamError ?? this.lastStreamError),
        busy: busy ?? this.busy,
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
  Future<void>? _writes;

  int get _nowMs => _now().millisecondsSinceEpoch;

  /// The injected clock, so the UI can compute ages against the same time source.
  DateTime now() => _now();

  /// Completes when every queued sample and event write has landed.
  Future<void> flush() => _writes ?? Future<void>.value();

  Future<void> start(SamplerConfig config) async {
    if (_status.running || _status.busy) return;
    _setBusy(true);
    try {
      final session = await _newSession(config);
      await _store.insertSession(session);
      _nextSeq = 0;
      _status = SamplerStatus(sessionId: session.id, lifecycle: _status.lifecycle, busy: true);
      await _listen(session.requestedIntervalS, session.requestedAccuracy);
    } finally {
      _setBusy(false);
    }
  }

  Future<bool> resumeIfOpen() async {
    if (_status.running) return true;
    if (_status.busy) return false;
    _setBusy(true);
    try {
      final session = await _store.openSession();
      if (session == null) return false;
      _nextSeq = await _store.nextSeq(session.id);
      _status = SamplerStatus(
        sessionId: session.id,
        sampleCount: await _store.sampleCount(session.id),
        lifecycle: _status.lifecycle,
        busy: true,
      );
      await _write(LabEvent(
        sessionId: session.id,
        timeUtcMs: _nowMs,
        kind: EventKind.appStart,
        detail: 'resumed open session',
      ));
      await _listen(session.requestedIntervalS, session.requestedAccuracy);
      return true;
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _status = _status.copyWith(busy: value);
    notifyListeners();
  }

  Future<void> _listen(int intervalS, RequestedAccuracy accuracy) async {
    _sub = _positions(intervalS, accuracy).listen(
      _onPosition,
      onError: (Object e) {
        _status = _status.copyWith(lastStreamError: e.toString());
        notifyListeners();
        logEvent(EventKind.error, e.toString());
      },
      cancelOnError: false,
    );
    _status = _status.copyWith(running: true, clearStreamError: true);
    notifyListeners();
    await logEvent(EventKind.stream, 'started');
  }

  Future<void> stop() async {
    if (!_status.running || _status.busy) return;
    _setBusy(true);
    try {
      await _sub?.cancel();
      _sub = null;
      await flush();
      await logEvent(EventKind.stream, 'stopped');
      final id = _status.sessionId;
      if (id != null) await _store.endSession(id, _nowMs);
      _status = _status.copyWith(running: false, clearSession: true);
    } finally {
      _setBusy(false);
    }
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

  /// Never throws: a failed write is recorded on [SamplerStatus.lastWriteError].
  Future<void> logEvent(EventKind kind, String detail) async {
    final id = _status.sessionId;
    if (id == null) return;
    try {
      await _write(LabEvent(sessionId: id, timeUtcMs: _nowMs, kind: kind, detail: detail));
    } catch (_) {
      // Already recorded by the queue's error handler.
    }
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
    // The chain head is created on first use so it belongs to the zone the
    // sampler runs in, not the zone it was constructed in.
    final next = (_writes ?? Future<void>.value()).then((_) => job());
    _writes = next.catchError((Object e, StackTrace st) {
      debugPrint('lab store write failed: $e\n$st');
      _status = _status.copyWith(lastWriteError: e.toString());
      notifyListeners();
    });
    return next;
  }

  Future<void> _write(LabEvent e) => _enqueue(() => _store.insertEvent(e)).then((_) {
        _status = _status.copyWith(eventRevision: _status.eventRevision + 1);
        notifyListeners();
      });

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
