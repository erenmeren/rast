import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../data/mock/mock_people.dart';
import '../../core/ids.dart';
import '../discovery/people_directory.dart';

const int maxMessageLength = 1000;

/// Threads: the seeded demo conversations on the mock, the member's open
/// matches on the server (loaded once, refreshed on every pair event, on
/// resume and after each send).
class ThreadsNotifier extends Notifier<List<Thread>> {
  bool get _server => ref.read(backendKindProvider) == BackendKind.supabase;
  final _failures = StreamController<String>.broadcast();

  /// A message the server refused or never received; the thread is refreshed
  /// so the optimistic copy disappears.
  Stream<String> get failures => _failures.stream;
  Future<void> _ready = Future.value();
  Future<void> get ready => _ready;

  @override
  List<Thread> build() {
    if (!_server) return seedThreads();
    final sub = ref.read(chatRepositoryProvider).changes().listen((_) => refresh());
    ref.onDispose(sub.cancel);
    _ready = refresh();
    return const [];
  }

  Future<void> refresh() async {
    if (!_server) return;
    try {
      final snapshot = await ref.read(chatRepositoryProvider).load();
      if (!ref.mounted) return;
      ref.read(peopleProvider.notifier).add(snapshot.people);
      final loaded = snapshot.threads;
      // keep a placeholder thread the server does not know yet (fresh match)
      final known = {for (final t in loaded) t.id};
      state = [...loaded, for (final t in state) if (!known.contains(t.id) && t.messages.isEmpty) t];
    } catch (_) {}
  }

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

  /// Returns the existing thread or creates one at the top: `match-<personId>`
  /// on the mock, the person's id on the server (one thread per person).
  Thread ensureThread(String personId) {
    final existing = byPerson(personId);
    if (existing != null) return existing;
    final thread = Thread(id: _server ? personId : 'match-$personId', personId: personId);
    state = [thread, ...state];
    return thread;
  }

  /// Trims, caps at 1000 characters, stamps HH:mm. Empty text is ignored.
  /// On the server the message shows at once and the RPC runs behind it; a
  /// closed pair makes the next refresh drop it again.
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
    if (_server) {
      ref.read(chatRepositoryProvider).send(thread.personId, newUuid(), clipped).then((seq) {
        if (seq == null) _failed(threadId, 'This conversation is no longer available.');
      }, onError: (Object _) => _failed(threadId, 'Your message did not reach the server. Check your connection and try again.'));
    }
    return true;
  }

  void _failed(String threadId, String message) {
    if (!ref.mounted) return;
    _failures.add(message);
    refresh();
  }

  void markRead(String threadId) {
    state = [for (final t in state) if (t.id == threadId) t.copyWith(unread: 0) else t];
    if (_server) ref.read(chatRepositoryProvider).markRead(threadId);
  }

  void removePerson(String personId) => state = state.where((t) => t.personId != personId).toList();

  void reset() => state = _server ? const [] : seedThreads();
  void clearAll() => state = const [];
}

final threadsProvider = NotifierProvider<ThreadsNotifier, List<Thread>>(ThreadsNotifier.new);
