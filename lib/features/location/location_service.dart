import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/ids.dart';
import '../../core/models/models.dart';
import '../../core/storage/preferences_store.dart';
import '../../data/repositories.dart';
import '../auth/session_notifier.dart';
import '../profile/settings_notifier.dart';

const int flushEvery = 5;
const Duration flushInterval = Duration(seconds: 60);
const int queueCap = 500;
const String queueKey = 'rast.location.queue';
const String seqKey = 'rast.location.seq';

class LocationStatus {
  const LocationStatus({this.running = false, this.pending = 0, this.lastFixAt, this.lastError});
  final bool running;
  final int pending;
  final DateTime? lastFixAt;
  final String? lastError;

  LocationStatus copyWith({bool? running, int? pending, DateTime? lastFixAt, String? lastError, bool clearError = false}) =>
      LocationStatus(
        running: running ?? this.running,
        pending: pending ?? this.pending,
        lastFixAt: lastFixAt ?? this.lastFixAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );
}

/// Samples while the member is active with location on; queues fixes in the
/// store and flushes them in small batches. Rebuilds (and so restarts the
/// stream) whenever the session phase or the location settings change.
class LocationService extends Notifier<LocationStatus> {
  StreamSubscription<Fix>? _sub;
  Timer? _timer;
  List<LocationSample> _queue = [];
  bool _flushing = false;

  PreferencesStore get _store => ref.read(preferencesStoreProvider);
  LocationRepository get _repo => ref.read(locationRepositoryProvider);

  @override
  LocationStatus build() {
    final active = ref.watch(sessionProvider.select((s) => s.phase == SessionPhase.active));
    final enabled = ref.watch(settingsProvider.select((s) => s.locationEnabled));
    final interval = ref.watch(settingsProvider.select((s) => s.intervalSeconds));
    _queue = _loadQueue();
    ref.onDispose(_stop);
    if (active && enabled) _start(interval);
    return LocationStatus(running: active && enabled, pending: _queue.length);
  }

  List<LocationSample> _loadQueue() {
    final raw = _store.getString(queueKey);
    if (raw == null) return [];
    try {
      return [for (final j in jsonDecode(raw) as List) LocationSample.fromJson((j as Map).cast())];
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveQueue() => _store.setString(queueKey, jsonEncode([for (final s in _queue) s.toJson()]));

  Future<void> _start(int interval) async {
    final device = await _repo.deviceId();
    if (!ref.mounted) return;
    _sub = _repo.fixes(interval).listen((fix) => _onFix(device, fix), onError: (Object e) {
      _stop();
      if (ref.mounted) state = state.copyWith(running: false, lastError: '$e');
    });
    if (_queue.isNotEmpty) _armTimer();
  }

  // the periodic flush exists only while something waits in the queue
  void _armTimer() => _timer ??= Timer.periodic(flushInterval, (_) => flush());

  void _disarmTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _stop() {
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _onFix(String device, Fix fix) async {
    final seq = (_store.getInt(seqKey) ?? 0) + 1;
    await _store.setInt(seqKey, seq);
    _queue.add(LocationSample(
      id: newUuid(), deviceId: device, seq: seq,
      lat: fix.lat, lon: fix.lon, accuracyM: fix.accuracyM, observedAt: fix.observedAt.toUtc(),
    ));
    if (_queue.length > queueCap) _queue = _queue.sublist(_queue.length - queueCap);
    await _saveQueue();
    if (!ref.mounted) return;
    state = state.copyWith(pending: _queue.length, lastFixAt: fix.observedAt.toUtc());
    if (_sub != null) _armTimer();
    if (_queue.length >= flushEvery) await flush();
  }

  /// Sends everything queued; keeps it on failure.
  Future<void> flush() async {
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final batch = List<LocationSample>.of(_queue);
    try {
      final accepted = (await _repo.upload(batch)).toSet();
      _queue = [for (final s in _queue) if (!accepted.contains(s.id) && !batch.any((b) => b.id == s.id)) s];
      await _saveQueue();
      if (_queue.isEmpty) _disarmTimer();
      if (ref.mounted) state = state.copyWith(pending: _queue.length, clearError: true);
    } catch (e) {
      if (ref.mounted) state = state.copyWith(lastError: '$e');
    } finally {
      _flushing = false;
    }
  }
}

final locationProvider = NotifierProvider<LocationService, LocationStatus>(LocationService.new);
