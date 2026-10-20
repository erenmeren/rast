import '../../core/models/models.dart';
import '../../core/storage/preferences_store.dart';
import '../repositories.dart';

/// Accepts the fixed demo code. No SMS is sent. Never ship this.
class MockAuthRepository implements AuthRepository {
  static const demoCode = '246810';

  @override
  Future<void> sendCode(String dial, String phone) async {}

  @override
  Future<bool> verify(String code) async => code == demoCode;
}

class MockSafetyRepository implements SafetyRepository {
  MockSafetyRepository(this.store);
  final PreferencesStore store;

  static const blockedKey = 'rast.safety.blocked';
  static const disconnectedKey = 'rast.safety.disconnected';
  static const reportsKey = 'rast.safety.reports';

  @override
  Future<SafetyState> load() async {
    final reports = <Report>[];
    for (final raw in store.getStringList(reportsKey) ?? const <String>[]) {
      final i = raw.indexOf('|');
      if (i <= 0) continue;
      final reason = raw.substring(i + 1);
      if (!reportReasons.contains(reason)) continue;
      reports.add(Report(personId: raw.substring(0, i), reason: reason));
    }
    return SafetyState(
      blocked: (store.getStringList(blockedKey) ?? const []).toSet(),
      disconnected: (store.getStringList(disconnectedKey) ?? const []).toSet(),
      reports: reports,
    );
  }

  @override
  Future<void> save(SafetyState state) async {
    await store.setStringList(blockedKey, state.blocked.toList());
    await store.setStringList(disconnectedKey, state.disconnected.toList());
    await store.setStringList(reportsKey, [for (final r in state.reports) '${r.personId}|${r.reason}']);
  }

  @override
  Future<void> clear() async {
    await store.remove(blockedKey);
    await store.remove(disconnectedKey);
    await store.remove(reportsKey);
  }
}

class MockIntroRepository implements IntroRepository {
  MockIntroRepository(this.store);
  final PreferencesStore store;
  static const key = 'rast.intro';

  @override
  IntroStatus status() {
    final raw = store.getString(key);
    return IntroStatus.values.firstWhere((s) => s.name == raw, orElse: () => IntroStatus.none);
  }

  @override
  Future<void> set(IntroStatus status) =>
      status == IntroStatus.none ? store.remove(key) : store.setString(key, status.name);
}

class MockEntitlementRepository implements EntitlementRepository {
  MockEntitlementRepository(this.store);
  final PreferencesStore store;
  static const key = 'rast.premium';

  @override
  bool isPremium() => store.getBool(key) ?? false;

  @override
  Future<void> setPremium(bool value) => store.setBool(key, value);
}

class MockSessionRepository implements SessionRepository {
  MockSessionRepository(this.store);
  final PreferencesStore store;
  static const phaseKey = 'rast.session.phase';
  static const verifiedKey = 'rast.session.verified';

  @override
  Session load() {
    final raw = store.getString(phaseKey);
    final phase = SessionPhase.values.firstWhere((p) => p.name == raw, orElse: () => SessionPhase.signedOut);
    return Session(phase: phase, verified: store.getBool(verifiedKey) ?? false);
  }

  @override
  Future<void> save(Session session) async {
    await store.setString(phaseKey, session.phase.name);
    await store.setBool(verifiedKey, session.verified);
  }

  @override
  Future<void> clear() async {
    await store.remove(phaseKey);
    await store.remove(verifiedKey);
  }
}

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this.store);
  final PreferencesStore store;

  static const _keys = [
    'rast.profile.age', 'rast.profile.gender', 'rast.profile.customGender', 'rast.profile.showGender',
    'rast.profile.photos', 'rast.profile.dial', 'rast.profile.phone',
    'rast.prefs.interests', 'rast.prefs.minAge', 'rast.prefs.maxAge',
  ];

  @override
  Profile load() {
    final photos = store.getStringList('rast.profile.photos');
    final genderRaw = store.getString('rast.profile.gender');
    return Profile(
      age: store.getInt('rast.profile.age'),
      gender: Gender.values.where((g) => g.name == genderRaw).firstOrNull,
      customGender: store.getString('rast.profile.customGender') ?? '',
      showGender: store.getBool('rast.profile.showGender') ?? false,
      photos: photos == null || photos.length != 4
          ? const [null, null, null, null]
          : [for (final p in photos) p.isEmpty ? null : p],
      dial: store.getString('rast.profile.dial') ?? '+44',
      phone: store.getString('rast.profile.phone') ?? '',
    );
  }

  @override
  Future<void> save(Profile p) async {
    if (p.age != null) {
      await store.setInt('rast.profile.age', p.age!);
    } else {
      await store.remove('rast.profile.age');
    }
    if (p.gender != null) {
      await store.setString('rast.profile.gender', p.gender!.name);
    } else {
      await store.remove('rast.profile.gender');
    }
    await store.setString('rast.profile.customGender', p.customGender);
    await store.setBool('rast.profile.showGender', p.showGender);
    await store.setStringList('rast.profile.photos', [for (final s in p.photos) s ?? '']);
    await store.setString('rast.profile.dial', p.dial);
    await store.setString('rast.profile.phone', p.phone);
  }

  @override
  Preferences loadPreferences() {
    final raw = store.getStringList('rast.prefs.interests');
    final interests = raw == null
        ? const {Interest.everyone}
        : {for (final i in Interest.values) if (raw.contains(i.name)) i};
    return Preferences(
      interests: interests.isEmpty ? const {Interest.everyone} : interests,
      minAge: store.getInt('rast.prefs.minAge') ?? 18,
      maxAge: store.getInt('rast.prefs.maxAge') ?? 99,
    );
  }

  @override
  Future<void> savePreferences(Preferences p) async {
    await store.setStringList('rast.prefs.interests', [for (final i in p.interests) i.name]);
    await store.setInt('rast.prefs.minAge', p.minAge);
    await store.setInt('rast.prefs.maxAge', p.maxAge);
  }

  @override
  Future<void> clear() async {
    for (final k in _keys) {
      await store.remove(k);
    }
  }
}
