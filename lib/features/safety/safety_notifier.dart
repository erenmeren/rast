import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../data/repositories.dart';
import '../discovery/people_directory.dart';

/// Blocks, permanent removals and reports. Loaded once from the repository,
/// then every change is applied locally and sent as an operation. The
/// server stays authoritative; this is the client mirror.
class SafetyNotifier extends Notifier<SafetyState> {
  @override
  SafetyState build() {
    _load();
    return SafetyState.empty;
  }

  Future<void> _load() async {
    final repo = ref.read(safetyRepositoryProvider);
    final loaded = await repo.load();
    final blocked = await repo.blockedPeople();
    if (!ref.mounted) return;
    ref.read(peopleProvider.notifier).add(blocked);
    state = _merge(state, loaded);
  }

  Future<void> refresh() => _load();

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

  bool isUnavailable(String? id) => id == null || !ref.knowsPerson(id) || state.isUnavailable(id);

  /// Applies the change at once, sends it, and puts the old state back when
  /// the server could not be reached. Returns false in that case.
  Future<bool> _apply(SafetyState next, Future<void> Function(SafetyRepository repo) op) async {
    final before = state;
    state = next;
    try {
      await op(ref.read(safetyRepositoryProvider));
      return true;
    } catch (_) {
      if (ref.mounted) state = before;
      return false;
    }
  }

  Future<bool> block(String id) {
    if (!ref.knowsPerson(id)) return Future.value(false);
    return _apply(state.copyWith(blocked: {...state.blocked, id}), (r) => r.block(id));
  }

  /// Removes only the block edge. A permanent removal stays.
  Future<bool> unblock(String id) => _apply(state.copyWith(blocked: {...state.blocked}..remove(id)), (r) => r.unblock(id));

  Future<bool> disconnect(String id) {
    if (!ref.knowsPerson(id)) return Future.value(false);
    return _apply(state.copyWith(disconnected: {...state.disconnected, id}), (r) => r.disconnect(id));
  }

  Future<bool> report(String id, String reason, {bool alsoBlock = false}) {
    if (!ref.knowsPerson(id) || !reportReasons.contains(reason)) return Future.value(false);
    if (state.reports.any((r) => r.personId == id && r.reason == reason)) return Future.value(true);
    return _apply(state.copyWith(reports: [...state.reports, Report(personId: id, reason: reason)]),
        (r) => r.report(id, reason, alsoBlock: alsoBlock));
  }

  Future<void> reset() async {
    state = SafetyState.empty;
    await ref.read(safetyRepositoryProvider).clear();
  }
}

final safetyProvider = NotifierProvider<SafetyNotifier, SafetyState>(SafetyNotifier.new);
