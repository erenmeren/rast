import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';

class PreferencesNotifier extends Notifier<Preferences> {
  @override
  Preferences build() => ref.read(profileRepositoryProvider).loadPreferences();

  void _set(Preferences p) {
    state = p;
    ref.read(profileRepositoryProvider).savePreferences(p);
  }

  void toggle(Interest interest) => _set(state.toggled(interest));
  void setRange(int min, int max) => _set(state.withRange(min, max));
  void replace(Preferences p) => _set(p);
  void reset() => _set(Preferences.defaults);
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, Preferences>(PreferencesNotifier.new);
