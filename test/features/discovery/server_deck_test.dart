import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/data/repositories.dart';
import 'package:rast/features/discovery/deck_notifier.dart';
import 'package:rast/features/discovery/eligibility.dart';
import 'package:rast/features/discovery/people_directory.dart';

import '../../helpers/app.dart';

Person card(String id, {bool likesYou = false}) => Person(
      id: id, age: 30, gender: Gender.woman, photo: 'sb:$id/0.jpg',
      photos: ['sb:$id/0.jpg', 'sb:$id/1.jpg', 'sb:$id/2.jpg', 'sb:$id/3.jpg'], likesYou: likesYou,
      delayHours: 0, hoursAgo: 0, distanceMeters: 0);

/// Scripted server: a fixed deck, one person who likes back.
class FakeDiscovery implements DiscoveryRepository {
  final log = <String>[];
  List<Person> deck = [card('a'), card('b'), card('c')];
  Set<String> likesMe = {'b'};
  Set<String> gone = {};

  @override
  Future<String> startSession() async {
    log.add('session');
    return 's1';
  }

  @override
  Future<CardPage> cards(String sessionId, {String? after}) async => CardPage([for (final p in deck) if (!gone.contains(p.id)) p], null);

  @override
  Future<LikeOutcome> like(String id) async {
    log.add('like $id');
    if (gone.contains(id)) return LikeOutcome.unavailable;
    return likesMe.contains(id) ? LikeOutcome.matched : LikeOutcome.liked;
  }

  @override
  Future<bool> pass(String id) async {
    log.add('pass $id');
    return !gone.contains(id);
  }

  String? lastPass;
  @override
  Future<String?> rewind() async {
    final p = RegExp(r'pass (\w+)').allMatches(log.join(' ')).lastOrNull?.group(1);
    return p != null && !gone.contains(p) ? p : null;
  }

  @override
  Future<LikesYouResult> likesYou() async => const LikesYouResult(premium: false, count: 0, previews: [], cards: []);
  @override
  Future<List<Connection>> connections() async => [];
  @override
  Future<Person?> personCard(String id) async => deck.where((p) => p.id == id).firstOrNull;
}

void main() {
  Future<(dynamic, FakeDiscovery)> server() async {
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
