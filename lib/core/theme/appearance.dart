import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/preferences_store.dart';

enum Appearance { system, light, dark }

const String appearanceKey = 'rast.appearance';

ThemeMode themeModeOf(Appearance a) => switch (a) {
      Appearance.system => ThemeMode.system,
      Appearance.light => ThemeMode.light,
      Appearance.dark => ThemeMode.dark,
    };

String appearanceLabel(Appearance a) => switch (a) {
      Appearance.system => 'System',
      Appearance.light => 'Light',
      Appearance.dark => 'Dark',
    };

/// Persisted appearance. System follows the device; an explicit choice stays
/// fixed. Read synchronously at bootstrap so the first frame is already right.
class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() {
    final saved = ref.read(preferencesStoreProvider).getString(appearanceKey);
    return Appearance.values.firstWhere(
      (a) => a.name == saved,
      orElse: () => Appearance.system,
    );
  }

  Future<void> set(Appearance value) async {
    state = value;
    await ref.read(preferencesStoreProvider).setString(appearanceKey, value.name);
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, Appearance>(AppearanceNotifier.new);
