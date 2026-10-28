import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/storage/preferences_store.dart';
import 'package:rast/data/supabase/location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_helpers.dart';

void main() {
  test('push token and notify flags round-trip', () async {
    final client = await liveClient();
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesStore(await SharedPreferences.getInstance());
    final device = await ensureDeviceId(client, store);
    await client.from('device').update({'push_token': 'live-test'}).eq('id', device);
    var row = await client.from('device').select('push_token').eq('id', device).single();
    expect(row['push_token'], 'live-test');
    await client.from('device').update({'push_token': null}).eq('id', device);
    final me = client.auth.currentUser!.id;
    await client.from('preferences').update({'notify_likes': false}).eq('account_id', me);
    row = await client.from('preferences').select('notify_likes').eq('account_id', me).single();
    expect(row['notify_likes'], isFalse);
    await client.from('preferences').update({'notify_likes': true}).eq('account_id', me);
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
