import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/models/models.dart';
import '../../core/storage/preferences_store.dart';
import '../mock/mock_repositories.dart';
import '../repositories.dart';

/// Photo source prefix for an uploaded original (`sb:<bucket path>`).
const String storagePrefix = 'sb:';

String _uid(SupabaseClient client) {
  final id = client.auth.currentUser?.id;
  if (id == null) throw const AuthException('not signed in');
  return id;
}

/// Local store as the synchronous cache, server as the truth: every save
/// writes the store, then the row. Incomplete profiles (no birth date or
/// gender yet) stay local until they can satisfy the table constraints.
class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this.client, this.cache, this.store);
  final SupabaseClient client;
  final MockProfileRepository cache;
  final PreferencesStore store;

  @override
  Profile load() => cache.load();

  @override
  Preferences loadPreferences() => cache.loadPreferences();

  @override
  Future<void> save(Profile p) async {
    await cache.save(p);
    if (p.birthDate == null || p.gender == null) return;
    final me = _uid(client);
    await client.from('account').upsert({'id': me}, onConflict: 'id', ignoreDuplicates: true);
    await client.from('profile').upsert({
      'account_id': me,
      'birth_date': isoDate(p.birthDate!),
      'gender': p.gender!.name,
      'custom_gender': p.customGender,
      'show_gender': p.showGender,
      'visible': MockSettingsRepository(store).load().visible,
    }, onConflict: 'account_id');
  }

  @override
  Future<void> savePreferences(Preferences p) async {
    await cache.savePreferences(p);
    final me = _uid(client);
    final settings = MockSettingsRepository(store).load();
    await client.from('account').upsert({'id': me}, onConflict: 'id', ignoreDuplicates: true);
    await client.from('preferences').upsert({
      'account_id': me,
      'interests': [for (final i in p.interests) i.name],
      'min_age': p.minAge,
      'max_age': p.maxAge,
      'delay_hours': settings.delayHours,
      'interval_s': settings.intervalSeconds,
    }, onConflict: 'account_id');
  }

  @override
  Future<void> clear() => cache.clear();
}

class SupabaseSettingsRepository implements SettingsRepository {
  SupabaseSettingsRepository(this.client, this.cache);
  final SupabaseClient client;
  final MockSettingsRepository cache;

  @override
  Settings load() => cache.load();

  /// Updates the row when it exists; before setup the value waits in the
  /// store and `savePreferences` carries it.
  Future<void> _prefs(Map<String, Object> patch) async {
    await client.from('preferences').update(patch).eq('account_id', _uid(client));
  }

  @override
  Future<void> setDelay(int hours) async {
    await cache.setDelay(hours);
    await _prefs({'delay_hours': hours});
  }

  @override
  Future<void> setInterval(int seconds) async {
    await cache.setInterval(seconds);
    await _prefs({'interval_s': seconds});
  }

  @override
  Future<void> setVisible(bool value) async {
    await cache.setVisible(value);
    await client.from('profile').update({'visible': value}).eq('account_id', _uid(client));
  }

  @override
  Future<void> setLocation(bool value) => cache.setLocation(value);
  @override
  Future<void> setNotifications(bool value) => cache.setNotifications(value);
  @override
  Future<void> clear() => cache.clear();
}

class SupabaseIntroRepository implements IntroRepository {
  SupabaseIntroRepository(this.client, this.cache);
  final SupabaseClient client;
  final MockIntroRepository cache;
  static const contentVersion = 1;

  @override
  IntroStatus status() => cache.status();

  @override
  Future<void> set(IntroStatus status) async {
    await cache.set(status);
    final me = _uid(client);
    if (status == IntroStatus.none) {
      await client.from('intro_progress').delete().eq('account_id', me);
      return;
    }
    await client.from('account').upsert({'id': me}, onConflict: 'id', ignoreDuplicates: true);
    await client.from('intro_progress').upsert({
      'account_id': me,
      'content_version': contentVersion,
      'completed_at': status == IntroStatus.complete ? DateTime.now().toUtc().toIso8601String() : null,
    }, onConflict: 'account_id');
  }
}

/// Premium comes from the entitlement table; nothing on the client can set it.
class SupabaseEntitlementRepository implements EntitlementRepository {
  SupabaseEntitlementRepository(this.cache);
  final MockEntitlementRepository cache;

  @override
  bool isPremium() => cache.isPremium();

  @override
  Future<void> setPremium(bool value) async {}
}

/// One round trip per table, then the store mirrors the server and the
/// session phase is derived from what exists.
class SupabaseSync implements BackendSync {
  SupabaseSync(this.client, this.store);
  final SupabaseClient client;
  final PreferencesStore store;

  @override
  Future<void> hydrate() async {
    final session = MockSessionRepository(store);
    final user = client.auth.currentUser;
    if (user == null) {
      await session.clear();
      return;
    }
    final me = user.id;
    final rows = await Future.wait([
      client.from('account').select('status').eq('id', me).maybeSingle(),
      client.from('profile').select().eq('account_id', me).maybeSingle(),
      client.from('preferences').select().eq('account_id', me).maybeSingle(),
      client.from('photo').select('slot, storage_path').eq('account_id', me).eq('state', 'ready').order('slot'),
      client.from('intro_progress').select('completed_at').eq('account_id', me).maybeSingle(),
      client.from('entitlement').select('product, status, valid_until').eq('account_id', me).eq('product', 'premium').maybeSingle(),
    ]);
    final account = rows[0] as Map<String, dynamic>?;
    final profile = rows[1] as Map<String, dynamic>?;
    final prefs = rows[2] as Map<String, dynamic>?;
    final photos = (rows[3] as List).cast<Map<String, dynamic>>();
    final intro = rows[4] as Map<String, dynamic>?;
    final entitlement = rows[5] as Map<String, dynamic>?;

    final slots = List<String?>.filled(4, null);
    for (final ph in photos) {
      final slot = ph['slot'] as int;
      if (slot >= 0 && slot < 4) slots[slot] = '$storagePrefix${ph['storage_path']}';
    }
    final phone = user.phone ?? '';
    await MockProfileRepository(store).save(Profile(
      birthDate: profile == null ? null : DateTime.tryParse(profile['birth_date'] as String)?.toUtc(),
      gender: profile == null ? null : Gender.values.where((g) => g.name == profile['gender']).firstOrNull,
      customGender: (profile?['custom_gender'] as String?) ?? '',
      showGender: (profile?['show_gender'] as bool?) ?? false,
      photos: slots,
      dial: '',
      phone: phone.isEmpty ? '' : '+$phone',
    ));
    if (prefs != null) {
      final names = (prefs['interests'] as List).cast<String>();
      await MockProfileRepository(store).savePreferences(Preferences(
        interests: {for (final i in Interest.values) if (names.contains(i.name)) i},
        minAge: prefs['min_age'] as int,
        maxAge: prefs['max_age'] as int,
      ));
    }
    final settings = MockSettingsRepository(store);
    if (prefs != null) {
      await settings.setDelay(prefs['delay_hours'] as int);
      await settings.setInterval(prefs['interval_s'] as int);
    }
    if (profile != null) await settings.setVisible(profile['visible'] as bool);
    final introStatus = intro == null
        ? IntroStatus.none
        : (intro['completed_at'] == null ? IntroStatus.pending : IntroStatus.complete);
    await MockIntroRepository(store).set(introStatus);
    final until = entitlement?['valid_until'] as String?;
    final premium = entitlement != null &&
        entitlement['status'] == 'active' &&
        (until == null || DateTime.parse(until).isAfter(DateTime.now()));
    await MockEntitlementRepository(store).setPremium(premium);

    final setupComplete = account?['status'] == 'active' &&
        profile != null &&
        prefs != null &&
        slots.every((s) => s != null);
    final phase = !setupComplete
        ? SessionPhase.onboarding
        : (introStatus == IntroStatus.complete ? SessionPhase.active : SessionPhase.introPending);
    await session.save(Session(phase: phase, verified: true));
  }
}
