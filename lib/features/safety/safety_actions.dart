import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../discovery/people_directory.dart';
import '../chat/threads_notifier.dart';
import '../discovery/deck_notifier.dart';
import 'safety_notifier.dart';

/// Cross-feature safety operations. Mirrors `removePerson` in the prototype.
class SafetyActions {
  SafetyActions(this.ref);
  final Ref ref;

  /// Block and/or permanently remove [id] and forget them everywhere.
  ///
  /// Without [block] this is "Remove connection": always permanent.
  /// With [block]: the block is reversible, but if a connection existed it is
  /// also removed permanently.
  bool removePerson(String id, {bool block = false}) {
    if (!ref.knowsPerson(id)) return false;
    final threads = ref.read(threadsProvider.notifier);
    final safety = ref.read(safetyProvider.notifier);
    final hadConnection = threads.byPerson(id) != null;
    if (block) safety.block(id);
    if (!block || hadConnection) safety.disconnect(id);
    threads.removePerson(id);
    ref.read(deckProvider.notifier).forget(id);
    return true;
  }

  /// Unblocking never restores a removed connection.
  void unblock(String id) => ref.read(safetyProvider.notifier).unblock(id);

  void report(String id, String reason, {required bool alsoBlock}) {
    ref.read(safetyProvider.notifier).report(id, reason, alsoBlock: alsoBlock);
    if (alsoBlock) removePerson(id, block: true);
  }
}

final safetyActionsProvider = Provider<SafetyActions>(SafetyActions.new);
