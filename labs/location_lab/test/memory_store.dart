import 'package:location_lab/lab_store.dart';
import 'package:location_lab/models.dart';

/// In-memory store for widget tests: every call completes in a microtask, so
/// the test's fake clock never waits on sqlite.
class MemoryLabStore implements LabStore {
  final Map<String, LabSession> _sessions = {};
  final List<Sample> _samples = [];
  final List<LabEvent> _events = [];

  @override
  Future<void> close() async {}

  @override
  Future<void> insertSession(LabSession s) async => _sessions[s.id] = s;

  @override
  Future<void> endSession(String id, int endedAtUtcMs) async {
    final s = _sessions[id]!;
    _sessions[id] = LabSession(
      id: s.id,
      deviceId: s.deviceId,
      deviceModel: s.deviceModel,
      osVersion: s.osVersion,
      appVersion: s.appVersion,
      startedAtUtcMs: s.startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs,
      requestedIntervalS: s.requestedIntervalS,
      requestedAccuracy: s.requestedAccuracy,
      ntpOffsetMs: s.ntpOffsetMs,
      notes: s.notes,
    );
  }

  @override
  Future<LabSession?> openSession() async =>
      _sessions.values.where((s) => s.endedAtUtcMs == null).firstOrNull;

  @override
  Future<List<LabSession>> sessions() async => _sessions.values.toList()
    ..sort((a, b) => b.startedAtUtcMs.compareTo(a.startedAtUtcMs));

  @override
  Future<void> insertSample(Sample s) async => _samples.add(s);

  @override
  Future<void> insertEvent(LabEvent e) async => _events.add(e);

  @override
  Future<List<Sample>> samples(String sessionId) async =>
      _samples.where((s) => s.sessionId == sessionId).toList()..sort((a, b) => a.seq.compareTo(b.seq));

  @override
  Future<List<LabEvent>> events(String sessionId) async =>
      _events.where((e) => e.sessionId == sessionId).toList();

  @override
  Future<int> sampleCount(String sessionId) async =>
      _samples.where((s) => s.sessionId == sessionId).length;

  @override
  Future<void> deleteSession(String id) async {
    _sessions.remove(id);
    _samples.removeWhere((s) => s.sessionId == id);
    _events.removeWhere((e) => e.sessionId == id);
  }
}
