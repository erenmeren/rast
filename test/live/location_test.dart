import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/storage/preferences_store.dart';
import 'package:rast/data/repositories.dart';
import 'package:rast/data/supabase/location_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_helpers.dart';

void main() {
  test('device row and one accepted sample', () async {
    final client = await liveClient();
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesStore(await SharedPreferences.getInstance());
    final repo = SupabaseLocationRepository(client, store);
    final device = await repo.deviceId();
    expect(await repo.deviceId(), device, reason: 'remembered in the store');
    final row = await client.from('device').select('id').eq('id', device).maybeSingle();
    expect(row, isNotNull);
    final now = DateTime.now().toUtc();
    final sample = LocationSample(id: '00000000-0000-4000-8000-${now.millisecondsSinceEpoch.toString().padLeft(12, '0').substring(0, 12)}',
        deviceId: device, seq: now.millisecondsSinceEpoch ~/ 1000, lat: 41.0, lon: 29.0, accuracyM: 9, observedAt: now);
    expect(await repo.upload([sample]), [sample.id]);
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
