import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rast/app/providers.dart';
import 'package:rast/data/repositories.dart';
import 'package:rast/features/location/location_service.dart';
import 'package:rast/features/profile/settings_notifier.dart';

import 'package:rast/core/storage/preferences_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/app.dart';
import '../helpers/fake_location.dart';

Fix fix(int n) => Fix(lat: 51.5 + n * 0.0001, lon: -0.1, accuracyM: 8, observedAt: DateTime.utc(2026, 10, 26, 12, 0, n));

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  Future<(ProviderContainer, FakeLocation)> running() async {
    final fake = FakeLocation();
    final c = await testContainer(extra: [locationRepositoryProvider.overrideWithValue(fake)]);
    makeActiveMember(c); // location enabled, visible, active
    c.listen(locationProvider, (_, _) {}); // the app keeps the service alive the same way
    await tick();
    return (c, fake);
  }

  test('starts sampling for an active member with location on, at the chosen interval', () async {
    final (c, fake) = await running();
    expect(c.read(locationProvider).running, isTrue);
    expect(fake.lastInterval, 30);
    c.read(settingsProvider.notifier).setInterval(60);
    await tick();
    expect(fake.streamsStarted, 2);
    expect(fake.lastInterval, 60);
    c.read(settingsProvider.notifier).setLocation(false);
    await tick();
    expect(c.read(locationProvider).running, isFalse);
  });

  test('fixes queue with increasing seq and the fix time; five of them flush as one batch', () async {
    final (c, fake) = await running();
    for (var i = 0; i < 4; i++) {
      fake.emit(fix(i));
    }
    await tick();
    expect(c.read(locationProvider).pending, 4);
    expect(fake.uploads, isEmpty);
    fake.emit(fix(4));
    await tick();
    expect(fake.uploads, hasLength(1));
    final batch = fake.uploads.single;
    expect([for (final s in batch) s.seq], [1, 2, 3, 4, 5]);
    expect(batch.first.observedAt, DateTime.utc(2026, 10, 26, 12, 0, 0));
    expect(batch.first.deviceId, 'dev-1');
    expect(c.read(locationProvider).pending, 0);
    expect(c.read(locationProvider).lastFixAt, DateTime.utc(2026, 10, 26, 12, 0, 4));
  });

  test('a failed flush keeps the samples and the next flush sends them all', () async {
    final (c, fake) = await running();
    fake.offline = true;
    for (var i = 0; i < 5; i++) {
      fake.emit(fix(i));
    }
    await tick();
    expect(c.read(locationProvider).pending, 5);
    expect(c.read(locationProvider).lastError, isNotNull);
    fake.offline = false;
    await c.read(locationProvider.notifier).flush();
    expect(fake.uploads.single, hasLength(5));
    expect(c.read(locationProvider).pending, 0);
    expect(c.read(locationProvider).lastError, isNull);
  });

  test('the queue survives a relaunch through the store and seq keeps counting', () async {
    final (c, fake) = await running();
    fake.emit(fix(0));
    fake.emit(fix(1));
    await tick();
    final sp = await SharedPreferences.getInstance();
    final again = ProviderContainer(overrides: [
      preferencesStoreProvider.overrideWithValue(PreferencesStore(sp)),
      locationRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(again.dispose);
    makeActiveMember(again);
    again.listen(locationProvider, (_, _) {});
    await tick();
    expect(again.read(locationProvider).pending, 2);
    fake.emit(fix(2));
    await tick();
    await again.read(locationProvider.notifier).flush();
    expect([for (final s in fake.uploads.single) s.seq], [1, 2, 3]);
  });

  test('without the platform permissions the service does not start and says why', () async {
    final fake = FakeLocation()..permitted = false;
    final c = await testContainer(extra: [locationRepositoryProvider.overrideWithValue(fake)]);
    makeActiveMember(c);
    c.listen(locationProvider, (_, _) {});
    await tick();
    expect(c.read(locationProvider).running, isFalse);
    expect(c.read(locationProvider).lastError, contains('Location access'));
    expect(fake.streamsStarted, 0);
  });

  test('a stream error stops the service and is shown', () async {
    final (c, fake) = await running();
    fake.fail(StateError('permission revoked'));
    await tick();
    expect(c.read(locationProvider).running, isFalse);
    expect(c.read(locationProvider).lastError, contains('permission revoked'));
  });
}
