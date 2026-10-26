import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../../core/storage/preferences_store.dart';
import '../repositories.dart';
import 'mock_people.dart';

/// Accepts the fixed demo code. No SMS is sent. Never ship this.
class MockAuthRepository implements AuthRepository {
  static const demoCode = '246810';

  @override
  Future<void> sendCode(String dial, String phone) async {}

  @override
  Future<bool> verify(String code) async => code == demoCode;

  @override
  Future<void> signOut() async {}
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

  Future<void> _save(SafetyState state) async {
    await store.setStringList(blockedKey, state.blocked.toList());
    await store.setStringList(disconnectedKey, state.disconnected.toList());
    await store.setStringList(reportsKey, [for (final r in state.reports) '${r.personId}|${r.reason}']);
  }

  // read-modify-write, one operation at a time, so two quick calls cannot
  // overwrite each other
  Future<void> _chain = Future.value();
  Future<void> _edit(SafetyState Function(SafetyState s) change) =>
      _chain = _chain.then((_) async => _save(change(await load())));

  @override
  Future<void> block(String id) => _edit((s) => s.copyWith(blocked: {...s.blocked, id}));
  @override
  Future<void> unblock(String id) => _edit((s) => s.copyWith(blocked: {...s.blocked}..remove(id)));
  @override
  Future<void> disconnect(String id) => _edit((s) => s.copyWith(disconnected: {...s.disconnected, id}));

  @override
  Future<void> report(String id, String reason, {required bool alsoBlock}) => _edit((s) {
        final reports = s.reports.any((r) => r.personId == id && r.reason == reason) ? s.reports : [...s.reports, Report(personId: id, reason: reason)];
        return s.copyWith(reports: reports, blocked: alsoBlock ? {...s.blocked, id} : null);
      });

  @override
  Future<List<Person>> hiddenPeople() async => const [];

  @override
  Future<void> deleteAccount() async {}

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

/// `YYYY-MM-DD` for a UTC calendar date.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `YYYY-MM-DD` as a UTC calendar date, whatever the device time zone.
DateTime? parseIsoDate(String? s) {
  if (s == null) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime.utc(d.year, d.month, d.day);
}

class MockProfileRepository implements ProfileRepository {
  MockProfileRepository(this.store);
  final PreferencesStore store;

  static const _keys = [
    'rast.profile.birthDate', 'rast.profile.gender', 'rast.profile.customGender', 'rast.profile.showGender',
    'rast.profile.photos', 'rast.profile.dial', 'rast.profile.phone',
    'rast.prefs.interests', 'rast.prefs.minAge', 'rast.prefs.maxAge',
  ];

  @override
  Profile load() {
    final photos = store.getStringList('rast.profile.photos');
    final genderRaw = store.getString('rast.profile.gender');
    return Profile(
      birthDate: parseIsoDate(store.getString('rast.profile.birthDate')),
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
    if (p.birthDate != null) {
      await store.setString('rast.profile.birthDate', isoDate(p.birthDate!));
    } else {
      await store.remove('rast.profile.birthDate');
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

class MockSettingsRepository implements SettingsRepository {
  MockSettingsRepository(this.store);
  final PreferencesStore store;

  static const intervalKey = 'rast.interval';
  static const delayKey = 'rast.delay';
  static const notificationsKey = 'rast.notifications';
  static const visibleKey = 'rast.visible';
  static const locationKey = 'rast.location';

  @override
  Settings load() {
    final interval = store.getInt(intervalKey);
    final delay = store.getInt(delayKey);
    return Settings(
      intervalSeconds: updateIntervalSeconds.contains(interval) ? interval! : defaultIntervalSeconds,
      delayHours: revealDelayHours.contains(delay) ? delay! : defaultDelayHours,
      notifications: store.getBool(notificationsKey) ?? true,
      visible: store.getBool(visibleKey) ?? true,
      locationEnabled: store.getBool(locationKey) ?? false,
    );
  }

  @override
  Future<void> setDelay(int hours) => store.setInt(delayKey, hours);
  @override
  Future<void> setInterval(int seconds) => store.setInt(intervalKey, seconds);
  @override
  Future<void> setVisible(bool value) => store.setBool(visibleKey, value);
  @override
  Future<void> setLocation(bool value) => store.setBool(locationKey, value);
  @override
  Future<void> setNotifications(bool value) => store.setBool(notificationsKey, value);

  @override
  Future<void> clear() async {
    for (final k in [intervalKey, delayKey, notificationsKey, visibleKey, locationKey]) {
      await store.remove(k);
    }
  }
}

class MockBackendSync implements BackendSync {
  @override
  Future<void> hydrate() async {}
}

/// The picked file is the photo. Nothing is uploaded.
class MockPhotoRepository implements PhotoRepository {
  @override
  Future<String> upload(int slot, String filePath) async => filePath;
  @override
  Future<void> remove(String source) async {}
  @override
  Future<ImageRequest?> resolve(String source) async => null;
}

/// The mock deck never goes through this; it exists so the production
/// code paths compile and tests can script it.
class MockDiscoveryRepository implements DiscoveryRepository {
  @override
  Future<String> startSession() async => 'mock';
  @override
  Future<CardPage> cards(String sessionId, {String? after}) async => CardPage(mockPeople, null);
  @override
  Future<LikeOutcome> like(String id) async => (personById(id)?.likesYou ?? false) ? LikeOutcome.matched : LikeOutcome.liked;
  @override
  Future<bool> pass(String id) async => true;
  @override
  Future<String?> rewind() async => null;
  @override
  Future<LikesYouResult> likesYou() async =>
      LikesYouResult(premium: false, count: 0, previews: const [], cards: [for (final p in mockPeople) if (p.likesYou) p]);
  @override
  Future<List<Connection>> connections() async => [];
  @override
  Future<Person?> personCard(String id) async => personById(id);
}

class MockChatRepository implements ChatRepository {
  @override
  Future<ChatSnapshot> load() async => ChatSnapshot(seedThreads(), const []);
  @override
  Future<int?> send(String targetId, String clientOpId, String body) async => 1;
  @override
  Stream<void> changes() => const Stream.empty();
  @override
  Future<void> markRead(String threadId) async {}
}
