import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/data/mock/mock_repositories.dart';
import 'package:rast/data/supabase/auth_repository.dart';
import 'package:rast/data/supabase/backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rast/core/storage/preferences_store.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'live_helpers.dart';

void main() {
  test('phone OTP sign-in through the adapter', () async {
    final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    final auth = SupabaseAuthRepository(client);
    await auth.sendCode('+90', '555 000 0001');
    expect(await auth.verify('000000'), isFalse, reason: 'a wrong code must not throw');
    expect(await auth.verify(testOtp), isTrue);
    expect(client.auth.currentUser?.phone, endsWith('5550000001'));

    SharedPreferences.setMockInitialValues({});
    final store = PreferencesStore(await SharedPreferences.getInstance());
    final session = SupabaseSessionRepository(client, MockSessionRepository(store));
    expect(session.load().verified, isTrue);
    await auth.signOut();
    expect(session.load(), same(Session.signedOut));
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
