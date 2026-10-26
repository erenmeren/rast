import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/preferences_store.dart';
import '../data/mock/mock_repositories.dart';
import '../data/supabase/auth_repository.dart';
import '../data/supabase/backend.dart';
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
  runApp(ProviderScope(overrides: overrides, child: const RastApp()));
}

/// The composition root for the production backend. Nothing else in the app
/// imports `data/supabase`.
Future<List<Override>> supabaseOverrides(PreferencesStore store) async {
  final backend = await Backend.init();
  return [
    backendProvider.overrideWithValue(backend),
    backendKindProvider.overrideWithValue(BackendKind.supabase),
    authRepositoryProvider.overrideWithValue(SupabaseAuthRepository(backend.client)),
    sessionRepositoryProvider.overrideWithValue(SupabaseSessionRepository(backend.client, MockSessionRepository(store))),
  ];
}
