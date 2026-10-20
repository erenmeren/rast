import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/preferences_store.dart';
import 'app.dart';

/// Loads device-local preferences before the first frame so the saved
/// appearance applies without a flash.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [preferencesStoreProvider.overrideWithValue(PreferencesStore(prefs))],
      child: const RastApp(),
    ),
  );
}
