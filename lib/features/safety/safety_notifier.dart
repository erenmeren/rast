import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
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
    ref.read(peopleProvider.notifier).add(await repo.blockedPeople());
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

  void block(String id) {
    if (!ref.knowsPerson(id)) return;
    state = state.copyWith(blocked: {...state.blocked, id});
    ref.read(safetyRepositoryProvider).block(id);
  }

  /// Removes only the block edge. A permanent removal stays.
  void unblock(String id) {
    state = state.copyWith(blocked: {...state.blocked}..remove(id));
    ref.read(safetyRepositoryProvider).unblock(id);
  }

  void disconnect(String id) {
    if (!ref.knowsPerson(id)) return;
    state = state.copyWith(disconnected: {...state.disconnected, id});
    ref.read(safetyRepositoryProvider).disconnect(id);
  }

  void report(String id, String reason, {bool alsoBlock = false}) {
    if (!ref.knowsPerson(id) || !reportReasons.contains(reason)) return;
    if (state.reports.any((r) => r.personId == id && r.reason == reason)) return;
    state = state.copyWith(reports: [...state.reports, Report(personId: id, reason: reason)]);
    ref.read(safetyRepositoryProvider).report(id, reason, alsoBlock: alsoBlock);
  }

  Future<void> reset() async {
    state = SafetyState.empty;
    await ref.read(safetyRepositoryProvider).clear();
  }
}

final safetyProvider = NotifierProvider<SafetyNotifier, SafetyState>(SafetyNotifier.new);
