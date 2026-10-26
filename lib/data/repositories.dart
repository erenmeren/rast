import '../core/models/models.dart';

/// Phone verification. Production: SMS provider + session lifecycle.
abstract class AuthRepository {
  Future<void> sendCode(String dial, String phone);
  Future<bool> verify(String code);
  Future<void> signOut();
}

/// Blocks, permanent removals and reports. Production: server-authoritative
/// pair records with idempotent operations.
abstract class SafetyRepository {
  Future<SafetyState> load();
  Future<void> save(SafetyState state);
  Future<void> clear();
}

/// Once-per-account introduction status.
abstract class IntroRepository {
  IntroStatus status();
  Future<void> set(IntroStatus status);
}

/// Premium entitlement. Production: store-verified, server-owned.
abstract class EntitlementRepository {
  bool isPremium();
  Future<void> setPremium(bool value);
}

/// Session phase and the mock member's own data between launches.
abstract class SessionRepository {
  Session load();
  Future<void> save(Session session);
  Future<void> clear();
}

/// Reveal delay, sampling interval and visibility live on the server;
/// notifications and the location flag stay on the device.
abstract class SettingsRepository {
  Settings load();
  Future<void> setDelay(int hours);
  Future<void> setInterval(int seconds);
  Future<void> setVisible(bool value);
  Future<void> setLocation(bool value);
  Future<void> setNotifications(bool value);
  Future<void> clear();
}

/// Pulls the signed-in member's server state into the local store so the
/// synchronous notifiers see it. The mock has nothing to pull.
abstract class BackendSync {
  Future<void> hydrate();
}

abstract class ProfileRepository {
  Profile load();
  Future<void> save(Profile profile);
  Preferences loadPreferences();
  Future<void> savePreferences(Preferences preferences);
  Future<void> clear();
}
