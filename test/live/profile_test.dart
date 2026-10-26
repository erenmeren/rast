import 'package:flutter_test/flutter_test.dart';
import 'package:rast/core/models/models.dart';
import 'package:rast/core/storage/preferences_store.dart';
import 'package:rast/data/mock/mock_repositories.dart';
import 'package:rast/data/supabase/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_helpers.dart';

Future<PreferencesStore> freshStore() async {
  SharedPreferences.setMockInitialValues({});
  return PreferencesStore(await SharedPreferences.getInstance());
}

void main() {
  test('profile, preferences, settings, intro and entitlement round-trip through hydrate', () async {
    final client = await liveClient();
    final store = await freshStore();
    final profiles = SupabaseProfileRepository(client, MockProfileRepository(store), store);
    final settings = SupabaseSettingsRepository(client, MockSettingsRepository(store));
    final intro = SupabaseIntroRepository(client, MockIntroRepository(store));

    await profiles.save(const Profile(birthDate: null, gender: Gender.woman)); // incomplete: cached only
    await profiles.save(Profile(birthDate: DateTime.utc(1995, 3, 2), gender: Gender.woman, showGender: true));
    await profiles.savePreferences(const Preferences(interests: {Interest.women, Interest.men}, minAge: 21, maxAge: 40));
    await settings.setDelay(4);
    await settings.setInterval(60);
    await settings.setVisible(true);
    await intro.set(IntroStatus.complete);

    final store2 = await freshStore();
    final sync = SupabaseSync(client, store2);
    await sync.hydrate();
    final p = MockProfileRepository(store2).load();
    expect(p.birthDate, DateTime.utc(1995, 3, 2));
    expect(p.gender, Gender.woman);
    expect(p.showGender, isTrue);
    expect(p.photos.where((s) => s != null && s.startsWith('sb:')).length, 4);
    final prefs = MockProfileRepository(store2).loadPreferences();
    expect(prefs.interests, {Interest.women, Interest.men});
    expect((prefs.minAge, prefs.maxAge), (21, 40));
    final s = MockSettingsRepository(store2).load();
    expect((s.delayHours, s.intervalSeconds, s.visible), (4, 60, true));
    expect(MockIntroRepository(store2).status(), IntroStatus.complete);
    expect(MockEntitlementRepository(store2).isPremium(), isFalse);
    expect(MockSessionRepository(store2).load().phase, SessionPhase.active);

    // leave the test user as the other live tests expect it
    await profiles.savePreferences(const Preferences());
    await settings.setDelay(0);
    await settings.setInterval(30);
  }, skip: live ? false : 'live project; run with --dart-define=RAST_LIVE=true');
}
