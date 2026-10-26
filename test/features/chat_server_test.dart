import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/features/chat/threads_notifier.dart';
import 'package:rast/features/discovery/people_directory.dart';

import '../helpers/app.dart';
import '../helpers/fake_chat.dart';
import '../helpers/fake_discovery.dart';

void main() {
  Future<(ProviderContainer, FakeChat)> server() async {
    final chat = FakeChat()
      ..threads = [
        Thread(id: 'b', personId: 'b', messages: const [Message(text: 'hey', own: false, time: '09:00')], unread: 1),
      ];
    final c = await testContainer(extra: [
      backendKindProvider.overrideWithValue(BackendKind.supabase),
      chatRepositoryProvider.overrideWithValue(chat),
    ]);
    makeActiveMember(c);
    c.read(peopleProvider.notifier).add([card('b')]);
    await c.read(threadsProvider.notifier).ready;
    return (c, chat);
  }

  test('threads load from the server and appear in Chats', () async {
    final (c, _) = await server();
    expect(c.read(threadsProvider).single.personId, 'b');
    expect(c.read(threadsProvider).single.unread, 1);
  });

  test('send appends at once and posts to the server; markRead is recorded', () async {
    final (c, chat) = await server();
    final threads = c.read(threadsProvider.notifier);
    expect(threads.send('b', '  hi  '), isTrue);
    expect(c.read(threadsProvider).single.last!.text, 'hi');
    await Future<void>.delayed(Duration.zero);
    expect(chat.log, ['send b hi']);
    threads.markRead('b');
    expect(c.read(threadsProvider).single.unread, 0);
    expect(chat.log.last, 'read b');
  });

  test('a server change refetches; ensureThread creates the thread for a fresh match', () async {
    final (c, chat) = await server();
    chat.threads = [
      ...chat.threads,
      Thread(id: 'a', personId: 'a', messages: const [], unread: 0),
    ];
    chat.emit();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect([for (final t in c.read(threadsProvider)) t.id], ['b', 'a']);
    expect(c.read(threadsProvider.notifier).ensureThread('z').id, 'z');
    expect(c.read(threadsProvider.notifier).ensureThread('b').id, 'b');
  });
}
