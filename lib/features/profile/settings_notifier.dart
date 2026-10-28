import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/models.dart';
import '../../core/rules/rules.dart';
import '../../data/repositories.dart';

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => ref.read(settingsRepositoryProvider).load();

  SettingsRepository get _repo => ref.read(settingsRepositoryProvider);

  void setInterval(int seconds) {
    if (!updateIntervalSeconds.contains(seconds)) return;
    state = state.copyWith(intervalSeconds: seconds);
    _repo.setInterval(seconds);
  }

  void setDelay(int hours) {
    if (!revealDelayHours.contains(hours)) return;
    state = state.copyWith(delayHours: hours);
    _repo.setDelay(hours);
  }

  void setVisible(bool value) {
    state = state.copyWith(visible: value);
    _repo.setVisible(value);
  }

  void setLocation(bool value) {
    state = state.copyWith(locationEnabled: value);
    _repo.setLocation(value);
  }

  void setNotify(NotifyKind kind, bool value) {
    state = state.withNotify(kind, value);
    _repo.setNotify(kind, value);
  }

  Future<void> reset() async {
    state = Settings.defaults;
    await _repo.clear();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
