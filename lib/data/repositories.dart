import '../core/models/models.dart';

/// Phone verification. Production: SMS provider + session lifecycle.
abstract class AuthRepository {
  Future<void> sendCode(String dial, String phone);
  Future<bool> verify(String code);
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

abstract class ProfileRepository {
  Profile load();
  Future<void> save(Profile profile);
  Preferences loadPreferences();
  Future<void> savePreferences(Preferences preferences);
  Future<void> clear();
}
