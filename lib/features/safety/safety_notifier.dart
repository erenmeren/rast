import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/people_directory.dart';
import '../../app/providers.dart';
import '../../core/models/models.dart';

/// Blocks, permanent removals and reports. Loaded once from the repository,
/// then every change is written back. Production keeps the server
/// authoritative; this is the client mirror.
class SafetyNotifier extends Notifier<SafetyState> {
  @override
  SafetyState build() {
    ref.read(safetyRepositoryProvider).load().then((loaded) {
      state = _merge(state, loaded);
    });
    return SafetyState.empty;
  }

  /// Local changes made before the load completes are kept.
  SafetyState _merge(SafetyState local, SafetyState loaded) => SafetyState(
        blocked: {...loaded.blocked, ...local.blocked}.where(ref.knowsPerson).toSet(),
        disconnected: {...loaded.disconnected, ...local.disconnected}.where(ref.knowsPerson).toSet(),
        reports: [
          ...loaded.reports,
          for (final r in local.reports)
            if (!loaded.reports.any((l) => l.personId == r.personId && l.reason == r.reason)) r,
        ],
      );

  void _set(SafetyState s) {
    state = s;
    ref.read(safetyRepositoryProvider).save(s);
  }

  bool isUnavailable(String? id) => id == null || !ref.knowsPerson(id) || state.isUnavailable(id);

  void block(String id) {
    if (!ref.knowsPerson(id)) return;
    _set(state.copyWith(blocked: {...state.blocked, id}));
  }

  /// Removes only the block edge. A permanent removal stays.
  void unblock(String id) => _set(state.copyWith(blocked: {...state.blocked}..remove(id)));

  void disconnect(String id) {
    if (!ref.knowsPerson(id)) return;
    _set(state.copyWith(disconnected: {...state.disconnected, id}));
  }

  void report(String id, String reason) {
    if (!ref.knowsPerson(id) || !reportReasons.contains(reason)) return;
    if (state.reports.any((r) => r.personId == id && r.reason == reason)) return;
    _set(state.copyWith(reports: [...state.reports, Report(personId: id, reason: reason)]));
  }

  Future<void> reset() async {
    state = SafetyState.empty;
    await ref.read(safetyRepositoryProvider).clear();
  }
}

final safetyProvider = NotifierProvider<SafetyNotifier, SafetyState>(SafetyNotifier.new);
