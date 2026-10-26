import 'package:flutter_test/flutter_test.dart';
import 'package:rast/data/supabase/safety_repository.dart';

import 'live_helpers.dart';

void main() {
  test('report, load and the blocked list (blocking the owner would end the live match, so no block here)', () async {
    final client = await liveClient();
    final safety = SupabaseSafetyRepository(client);
    final connections = (await client.rpc('connections'))['connections'] as List;
    final owner = connections.first['card']['account_id'] as String;

    await safety.report(owner, 'Scam or spam', alsoBlock: false);
    final state = await safety.load();
    expect(state.reports.any((r) => r.personId == owner && r.reason == 'Scam or spam'), isTrue);
    expect(state.blocked, isEmpty);
    expect(state.disconnected, isEmpty);
    expect(await safety.blockedPeople(), isEmpty);
    await safety.unblock('00000000-0000-0000-0000-000000000009'); // a no-op must not throw
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
