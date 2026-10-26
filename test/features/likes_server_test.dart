import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/data/repositories.dart';
import 'package:rast/features/discovery/eligibility.dart';
import 'package:rast/features/likes/likes_notifier.dart';

import '../helpers/app.dart';
import '../helpers/fake_discovery.dart';

void main() {
  Future<ProviderContainer> server(FakeDiscovery fake, {bool premium = false}) async {
    final c = await testContainer(prefs: {'rast.premium': premium}, extra: [
      backendKindProvider.overrideWithValue(BackendKind.supabase),
      discoveryRepositoryProvider.overrideWithValue(fake),
    ]);
    makeActiveMember(c);
    await c.read(likesProvider.notifier).ready;
    return c;
  }

  test('free member sees locked previews with ages and no identity', () async {
    final fake = FakeDiscovery()
      ..likes = const LikesYouResult(premium: false, count: 2, previews: [LikePreview('tok1', 27), LikePreview('tok2', 31)], cards: []);
    final c = await server(fake);
    final people = c.read(incomingLikesProvider);
    expect([for (final p in people) p.photo], ['preview:tok1', 'preview:tok2']);
    expect([for (final p in people) p.age], [27, 31]);
    expect(people.every((p) => p.likesYou), isTrue);
    expect(people.every((p) => p.photos.isEmpty && p.gender == null), isTrue);
  });

  test('premium member gets the cards', () async {
    final fake = FakeDiscovery()
      ..likes = LikesYouResult(premium: true, count: 1, previews: const [], cards: [card('b', likesYou: true)]);
    final c = await server(fake, premium: true);
    expect([for (final p in c.read(incomingLikesProvider)) p.id], ['b']);
    expect(c.read(incomingLikesProvider).single.photos, hasLength(4));
  });
}
