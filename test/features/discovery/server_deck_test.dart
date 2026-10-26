import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/data/repositories.dart';
import 'package:rast/features/discovery/deck_notifier.dart';
import 'package:rast/features/discovery/eligibility.dart';
import 'package:rast/features/discovery/people_directory.dart';

import '../../helpers/app.dart';
import '../../helpers/fake_discovery.dart';

void main() {
  Future<(ProviderContainer, FakeDiscovery)> server() async {
    final fake = FakeDiscovery();
    final c = await testContainer(extra: [
      backendKindProvider.overrideWithValue(BackendKind.supabase),
      discoveryRepositoryProvider.overrideWithValue(fake),
    ]);
    makeActiveMember(c);
    await c.read(deckProvider.notifier).ready;
    return (c, fake);
  }

  test('cards arrive in server order and fill the directory', () async {
    final (c, fake) = await server();
    expect(c.read(deckProvider).order, ['a', 'b', 'c']);
    expect([for (final p in c.read(eligiblePeopleProvider)) p.id], ['a', 'b', 'c']);
    expect(c.read(peopleProvider.notifier).byId('b')?.age, 30);
    expect(fake.log, ['session']);
  });

  test('like: matched removes the card and reports the match', () async {
    final (c, fake) = await server();
    expect(await c.read(deckProvider.notifier).like('b'), LikeOutcome.matched);
    expect(await c.read(deckProvider.notifier).like('a'), LikeOutcome.liked);
    expect([for (final p in c.read(eligiblePeopleProvider)) p.id], ['c']);
    fake.gone.add('c');
    expect(await c.read(deckProvider.notifier).like('c'), LikeOutcome.unavailable);
    expect([for (final p in c.read(eligiblePeopleProvider)) p.id], isEmpty, reason: 'an unavailable card leaves the deck too');
  });

  test('pass hides, rewind restores at the top', () async {
    final (c, fake) = await server();
    final deck = c.read(deckProvider.notifier);
    await deck.pass('a');
    expect([for (final p in c.read(eligiblePeopleProvider)) p.id], ['b', 'c']);
    expect(await deck.rewind(), 'a');
    expect([for (final p in c.read(eligiblePeopleProvider)) p.id], ['a', 'b', 'c']);
    fake.gone.add('b');
    await deck.pass('b');
    expect(await deck.rewind(), isNull);
    expect(fake.log.last, 'pass b');
  });
}
