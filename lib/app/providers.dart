import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/storage/preferences_store.dart';
import '../data/mock/mock_repositories.dart';
import '../data/repositories.dart';

/// Composition root. Every repository defaults to its mock; production
/// adapters replace these overrides at bootstrap, not inside screens.
final authRepositoryProvider = Provider<AuthRepository>((ref) => MockAuthRepository());
final safetyRepositoryProvider =
    Provider<SafetyRepository>((ref) => MockSafetyRepository(ref.watch(preferencesStoreProvider)));
final introRepositoryProvider =
    Provider<IntroRepository>((ref) => MockIntroRepository(ref.watch(preferencesStoreProvider)));
final entitlementRepositoryProvider =
    Provider<EntitlementRepository>((ref) => MockEntitlementRepository(ref.watch(preferencesStoreProvider)));
final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) => MockSessionRepository(ref.watch(preferencesStoreProvider)));
final profileRepositoryProvider =
    Provider<ProfileRepository>((ref) => MockProfileRepository(ref.watch(preferencesStoreProvider)));
final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => MockSettingsRepository(ref.watch(preferencesStoreProvider)));
final backendSyncProvider = Provider<BackendSync>((ref) => MockBackendSync());
final photoRepositoryProvider = Provider<PhotoRepository>((ref) => MockPhotoRepository());
final discoveryRepositoryProvider = Provider<DiscoveryRepository>((ref) => MockDiscoveryRepository());
final chatRepositoryProvider = Provider<ChatRepository>((ref) => MockChatRepository());
final locationRepositoryProvider = Provider<LocationRepository>((ref) => MockLocationRepository());
final pushRepositoryProvider = Provider<PushRepository>((ref) => MockPushRepository());

/// Which backend bootstrap wired. Screens may branch on it for copy
/// (demo hints) and for the data source of the feed.
enum BackendKind { mock, supabase }

final backendKindProvider = Provider<BackendKind>((ref) => BackendKind.mock);

/// Injected clock and randomness for deterministic tests.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
final randomProvider = Provider<Random>((ref) => Random());

/// The moment the mock encounters are measured from (app start).
final sampleTimeProvider = Provider<DateTime>((ref) => ref.watch(clockProvider)());
