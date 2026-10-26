import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/preferences_store.dart';
import '../data/mock/mock_repositories.dart';
import '../data/supabase/auth_repository.dart';
import '../data/supabase/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import '../data/supabase/chat_repository.dart';
import '../data/supabase/discovery_repository.dart';
import '../data/supabase/photo_repository.dart';
import '../data/supabase/profile_repository.dart';
import '../data/supabase/safety_repository.dart';
import '../core/models/models.dart';
import '../features/auth/session_notifier.dart';
import 'app.dart';
import 'providers.dart';

/// `--dart-define=RAST_BACKEND=supabase` wires the production adapters;
/// anything else keeps the mock.
const String _backendFlag = String.fromEnvironment('RAST_BACKEND');

/// Loads device-local preferences before the first frame so the saved
/// appearance applies without a flash, then wires the chosen backend.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final store = PreferencesStore(prefs);
  final overrides = <Override>[preferencesStoreProvider.overrideWithValue(store)];
  if (_backendFlag == 'supabase') overrides.addAll(await supabaseOverrides(store));
  final container = ProviderContainer(overrides: overrides);
  if (_backendFlag == 'supabase') _watchSession(container);
  runApp(UncontrolledProviderScope(container: container, child: const RastApp()));
}

/// A session the server ended (revoked, unrefreshable) signs the member out
/// here too, so no screen keeps acting on a dead token.
void _watchSession(ProviderContainer container) {
  final client = container.read(backendProvider).client;
  client.auth.onAuthStateChange.listen((change) {
    if (change.event != AuthChangeEvent.signedOut) return;
    if (container.read(sessionProvider).phase == SessionPhase.signedOut) return;
    container.read(sessionProvider.notifier).logOut();
  });
}

/// The composition root for the production backend. Nothing else in the app
/// imports `data/supabase`.
Future<List<Override>> supabaseOverrides(PreferencesStore store) async {
  final backend = await Backend.init();
  final client = backend.client;
  final sync = SupabaseSync(client, store);
  // A returning member's store may be empty (reinstall) or stale.
  if (client.auth.currentSession != null) {
    try {
      await sync.hydrate().timeout(const Duration(seconds: 5));
    } catch (_) {
      // offline at start: the store still holds the last known state
    }
  }
  return [
    backendProvider.overrideWithValue(backend),
    backendKindProvider.overrideWithValue(BackendKind.supabase),
    backendSyncProvider.overrideWithValue(sync),
    authRepositoryProvider.overrideWithValue(SupabaseAuthRepository(client)),
    sessionRepositoryProvider.overrideWithValue(SupabaseSessionRepository(client, MockSessionRepository(store))),
    profileRepositoryProvider.overrideWithValue(SupabaseProfileRepository(client, MockProfileRepository(store), store)),
    settingsRepositoryProvider.overrideWithValue(SupabaseSettingsRepository(client, MockSettingsRepository(store))),
    introRepositoryProvider.overrideWithValue(SupabaseIntroRepository(client, MockIntroRepository(store))),
    entitlementRepositoryProvider.overrideWithValue(SupabaseEntitlementRepository(MockEntitlementRepository(store))),
    photoRepositoryProvider.overrideWithValue(SupabasePhotoRepository(client)),
    discoveryRepositoryProvider.overrideWithValue(SupabaseDiscoveryRepository(client)),
    chatRepositoryProvider.overrideWithValue(SupabaseChatRepository(client, store)),
    safetyRepositoryProvider.overrideWithValue(SupabaseSafetyRepository(client)),
  ];
}
