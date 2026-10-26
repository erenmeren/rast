import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/ui/photo_image.dart';
import 'package:rast/data/repositories.dart';
import 'package:rast/data/supabase/profile_repository.dart';
import 'package:rast/features/auth/session_notifier.dart';
import 'package:rast/features/chat/threads_notifier.dart';
import 'package:rast/features/discovery/deck_notifier.dart';
import 'package:rast/features/discovery/people_directory.dart';
import 'package:rast/features/likes/likes_notifier.dart';
import 'package:rast/features/safety/safety_notifier.dart';

import '../helpers/app.dart';
import '../helpers/fake_chat.dart';
import '../helpers/fake_discovery.dart';
import '../helpers/fake_safety.dart';

class CountingPhotos implements PhotoRepository {
  int resolves = 0;
  @override
  Future<String> upload(int slot, String filePath) async => filePath;
  @override
  Future<void> remove(String source) async {}
  @override
  Future<ImageRequest?> resolve(String source) async {
    resolves++;
    return null;
  }
}

class ThrowingSync implements BackendSync {
  @override
  Future<void> hydrate() async => throw Exception('offline');
}

void main() {
  Future<(ProviderContainer, FakeDiscovery, FakeChat, FakeSafety)> server() async {
    final discovery = FakeDiscovery();
    final chat = FakeChat()
      ..people = [card('b')]
      ..threads = [Thread(id: 'b', personId: 'b', messages: const [], unread: 0)];
    final safety = FakeSafety();
    final c = await testContainer(extra: [
      backendKindProvider.overrideWithValue(BackendKind.supabase),
      discoveryRepositoryProvider.overrideWithValue(discovery),
      chatRepositoryProvider.overrideWithValue(chat),
      safetyRepositoryProvider.overrideWithValue(safety),
    ]);
    makeActiveMember(c);
    await c.read(deckProvider.notifier).ready;
    await c.read(threadsProvider.notifier).ready;
    await c.read(likesProvider.notifier).ready;
    await Future<void>.delayed(Duration.zero);
    return (c, discovery, chat, safety);
  }

  test('log-out forgets the previous member: people, deck, threads, likes, safety', () async {
    final (c, _, _, _) = await server();
    expect(c.read(peopleProvider).keys, containsAll(['a', 'b', 'c']));
    await c.read(sessionProvider.notifier).logOut();
    expect(c.read(peopleProvider), isEmpty);
    expect(c.read(deckProvider).order, isEmpty);
    expect(c.read(threadsProvider), isEmpty);
    expect(c.read(likesProvider), isNull);
    expect(c.read(safetyProvider).blocked, isEmpty);
  });

  test('refreshFromStore after sign-in rebuilds the server notifiers', () async {
    final (c, discovery, chat, _) = await server();
    discovery.deck = [card('z')];
    chat.people = [card('y')];
    chat.threads = [Thread(id: 'y', personId: 'y', messages: const [], unread: 0)];
    c.read(sessionProvider.notifier).refreshFromStore();
    await c.read(deckProvider.notifier).ready;
    await c.read(threadsProvider.notifier).ready;
    expect(c.read(deckProvider).order, ['z']);
    expect(c.read(threadsProvider).single.id, 'y');
    expect(c.read(peopleProvider).keys, containsAll(['z', 'y']));
  });

  test('a like that fails offline leaves the deck as it was and surfaces a failure', () async {
    final (c, discovery, _, _) = await server();
    discovery.offline = true;
    await expectLater(c.read(deckProvider.notifier).like('a'), throwsA(isA<BackendFailure>()));
    expect(c.read(deckProvider).order, ['a', 'b', 'c']);
    expect(c.read(deckProvider).liked, isEmpty);
    await expectLater(c.read(deckProvider.notifier).pass('a'), throwsA(isA<BackendFailure>()));
    expect(c.read(deckProvider).passed, isEmpty);
    expect(c.read(deckProvider).history, isEmpty);
  });

  test('a block that fails offline is reverted', () async {
    final (c, _, _, safety) = await server();
    safety.offline = true;
    await c.read(safetyProvider.notifier).block('b');
    expect(c.read(safetyProvider).blocked, isEmpty);
    safety.offline = false;
    await c.read(safetyProvider.notifier).block('b');
    expect(c.read(safetyProvider).blocked, {'b'});
    expect(safety.log, ['block b', 'block b']);
  });

  test('birth dates survive hydrate in any time zone', () {
    final p = SupabaseSync.profileFromRows(
      profile: {'birth_date': '1995-03-02', 'gender': 'woman', 'custom_gender': '', 'show_gender': true},
      photos: const [],
      phone: '905550000001',
    );
    expect(p.birthDate, DateTime.utc(1995, 3, 2));
    expect(p.gender, Gender.woman);
    expect(p.phone, '+905550000001');
  });

  testWidgets('a failed hydrate after a correct code still moves the member on', (tester) async {
    final c = await testContainer(extra: [backendSyncProvider.overrideWithValue(ThrowingSync())]);
    c.read(sessionProvider.notifier).startSignup();
    await pumpRast(tester, c, initialLocation: '/auth/verify');
    await tester.enterText(find.bySemanticsLabel('Verification code').last, '246810');
    await tester.tap(find.text('Verify'));
    await tester.pumpAndSettle();
    expect(currentPath(c), '/setup/about');
  });

  testWidgets('a remote photo is resolved once per source, not once per build', (tester) async {
    final photos = CountingPhotos();
    final c = await testContainer(extra: [photoRepositoryProvider.overrideWithValue(photos)]);
    final key = GlobalKey<_RebuildState>();
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: MaterialApp(home: _Rebuild(key: key))));
    await tester.pump();
    key.currentState!.bump();
    await tester.pump();
    key.currentState!.bump();
    await tester.pump();
    expect(photos.resolves, 1);
  });
}

class _Rebuild extends StatefulWidget {
  const _Rebuild({super.key});
  @override
  State<_Rebuild> createState() => _RebuildState();
}

class _RebuildState extends State<_Rebuild> {
  int n = 0;
  void bump() => setState(() => n++);
  @override
  Widget build(BuildContext context) => Column(children: [Text('$n'), const SizedBox(width: 50, height: 50, child: PhotoImage('sb:x/y.jpg'))]);
}
