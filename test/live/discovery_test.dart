import 'package:flutter_test/flutter_test.dart';
import 'package:rast/data/supabase/discovery_repository.dart';

import 'live_helpers.dart';

void main() {
  test('session, cards, likes you, connections and person_card answer', () async {
    final client = await liveClient();
    final d = SupabaseDiscoveryRepository(client);
    final session = await d.startSession();
    expect(session, isNotEmpty);
    final page = await d.cards(session);
    expect(page.next, isNull);
    for (final p in page.cards) {
      expect(p.photos, hasLength(4));
      expect(p.photos.first, startsWith('sb:'));
    }
    final likes = await d.likesYou();
    expect(likes.premium, isFalse);
    expect(likes.count, likes.previews.length);
    final connections = await d.connections();
    expect(connections, isNotEmpty, reason: 'the test user is matched with the owner');
    final partner = connections.first.person;
    expect(partner.photos, hasLength(4));
    expect((await d.personCard(partner.id))?.id, partner.id);
    expect(await d.personCard('00000000-0000-0000-0000-000000000009'), isNull);
    expect(await d.rewind(), isNull, reason: 'no pass is pending for the test user');
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
