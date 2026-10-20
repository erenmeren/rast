import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../../core/storage/preferences_store.dart';

class SettingsNotifier extends Notifier<Settings> {
  static const intervalKey = 'rast.interval';
  static const delayKey = 'rast.delay';
  static const notificationsKey = 'rast.notifications';
  static const visibleKey = 'rast.visible';
  static const locationKey = 'rast.location';

  @override
  Settings build() {
    final store = ref.read(preferencesStoreProvider);
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

  PreferencesStore get _store => ref.read(preferencesStoreProvider);

  void setInterval(int seconds) {
    if (!updateIntervalSeconds.contains(seconds)) return;
    state = state.copyWith(intervalSeconds: seconds);
    _store.setInt(intervalKey, seconds);
  }

  void setDelay(int hours) {
    if (!revealDelayHours.contains(hours)) return;
    state = state.copyWith(delayHours: hours);
    _store.setInt(delayKey, hours);
  }

  void setVisible(bool value) {
    state = state.copyWith(visible: value);
    _store.setBool(visibleKey, value);
  }

  void setLocation(bool value) {
    state = state.copyWith(locationEnabled: value);
    _store.setBool(locationKey, value);
  }

  void setNotifications(bool value) {
    state = state.copyWith(notifications: value);
    _store.setBool(notificationsKey, value);
  }

  Future<void> reset() async {
    state = Settings.defaults;
    for (final k in [intervalKey, delayKey, notificationsKey, visibleKey, locationKey]) {
      await _store.remove(k);
    }
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
