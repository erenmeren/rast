import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../data/mock/mock_people.dart';

const int maxMessageLength = 1000;

class ThreadsNotifier extends Notifier<List<Thread>> {
  @override
  List<Thread> build() => seedThreads();

  Thread? byId(String? id) {
    for (final t in state) {
      if (t.id == id) return t;
    }
    return null;
  }

  Thread? byPerson(String? personId) {
    for (final t in state) {
      if (t.personId == personId) return t;
    }
    return null;
  }

  /// Returns the existing thread or creates `match-<personId>` at the top.
  Thread ensureThread(String personId) {
    final existing = byPerson(personId);
    if (existing != null) return existing;
    final thread = Thread(id: 'match-$personId', personId: personId);
    state = [thread, ...state];
    return thread;
  }

  /// Trims, caps at 1000 characters, stamps HH:mm. Empty text is ignored.
  bool send(String threadId, String text) {
    final body = text.trim();
    if (body.isEmpty) return false;
    final thread = byId(threadId);
    if (thread == null) return false;
    final now = ref.read(clockProvider)();
    final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final clipped = body.length > maxMessageLength ? body.substring(0, maxMessageLength) : body;
    state = [
      for (final t in state)
        if (t.id == threadId) t.copyWith(messages: [...t.messages, Message(text: clipped, own: true, time: time)]) else t,
    ];
    return true;
  }

  void markRead(String threadId) =>
      state = [for (final t in state) if (t.id == threadId) t.copyWith(unread: 0) else t];

  void removePerson(String personId) => state = state.where((t) => t.personId != personId).toList();

  void reset() => state = seedThreads();
  void clearAll() => state = const [];
}

final threadsProvider = NotifierProvider<ThreadsNotifier, List<Thread>>(ThreadsNotifier.new);
