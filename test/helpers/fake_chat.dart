import 'dart:async';

import 'package:rast/core/models/models.dart';
import 'package:rast/data/repositories.dart';

/// Scripted chat server: threads keyed by the other person's id.
class FakeChat implements ChatRepository {
  List<Thread> threads = [];
  final log = <String>[];
  final _changes = StreamController<void>.broadcast();
  bool unavailable = false;

  List<Person> people = [];
  @override
  Future<ChatSnapshot> load() async => ChatSnapshot(threads, people);

  @override
  Future<int?> send(String targetId, String clientOpId, String body) async {
    log.add('send $targetId $body');
    if (unavailable) return null;
    final seq = (threads.where((t) => t.id == targetId).firstOrNull?.messages.length ?? 0) + 1;
    threads = [
      for (final t in threads)
        if (t.id == targetId) t.copyWith(messages: [...t.messages, Message(text: body, own: true, time: '12:00')]) else t,
    ];
    return seq;
  }

  @override
  Stream<void> changes() => _changes.stream;

  void emit() => _changes.add(null);

  @override
  Future<void> markRead(String threadId) async => log.add('read $threadId');
}
