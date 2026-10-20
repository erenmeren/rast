import '../rules/rules.dart';

/// Timing, visibility and notification choices.
class Settings {
  const Settings({
    this.intervalSeconds = defaultIntervalSeconds,
    this.delayHours = defaultDelayHours,
    this.visible = true,
    this.locationEnabled = false,
    this.notifications = true,
  });

  final int intervalSeconds;
  final int delayHours;
  final bool visible;
  final bool locationEnabled;
  final bool notifications;

  static const defaults = Settings();

  Settings copyWith({
    int? intervalSeconds,
    int? delayHours,
    bool? visible,
    bool? locationEnabled,
    bool? notifications,
  }) =>
      Settings(
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        delayHours: delayHours ?? this.delayHours,
        visible: visible ?? this.visible,
        locationEnabled: locationEnabled ?? this.locationEnabled,
        notifications: notifications ?? this.notifications,
      );
}
