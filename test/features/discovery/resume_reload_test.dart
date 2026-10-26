import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/features/discovery/deck_notifier.dart';

import '../../helpers/app.dart';
import '../../helpers/fake_discovery.dart';

void main() {
  testWidgets('an empty deck reloads on resume; a deck with cards is left alone', (tester) async {
    final fake = FakeDiscovery();
    final c = await testContainer(extra: [
      backendKindProvider.overrideWithValue(BackendKind.supabase),
      discoveryRepositoryProvider.overrideWithValue(fake),
    ]);
    makeActiveMember(c);
    await pumpRast(tester, c);
    final deck = c.read(deckProvider.notifier);
    await deck.ready;
    expect(c.read(deckProvider).order, ['a', 'b', 'c']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(fake.log.where((l) => l == 'session').length, 1, reason: 'cards still on the deck: no new session');

    for (final id in ['a', 'b', 'c']) {
      await deck.pass(id);
    }
    expect(c.read(deckProvider).order, isEmpty);
    fake.deck = [card('d')];

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await c.read(deckProvider.notifier).ready;
    expect(c.read(deckProvider).order, ['d']);
  });
}
