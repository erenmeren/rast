import '../rules/rules.dart';

/// The three push notification kinds a member can switch separately.
enum NotifyKind { matches, likes, messages }

/// Timing, visibility and notification choices.
class Settings {
  const Settings({
    this.intervalSeconds = defaultIntervalSeconds,
    this.delayHours = defaultDelayHours,
    this.visible = true,
    this.locationEnabled = false,
    this.notifyMatches = true,
    this.notifyLikes = true,
    this.notifyMessages = true,
  });

  final int intervalSeconds;
  final int delayHours;
  final bool visible;
  final bool locationEnabled;
  final bool notifyMatches;
  final bool notifyLikes;
  final bool notifyMessages;

  static const defaults = Settings();

  bool get anyNotify => notifyMatches || notifyLikes || notifyMessages;

  bool notify(NotifyKind kind) => switch (kind) {
        NotifyKind.matches => notifyMatches,
        NotifyKind.likes => notifyLikes,
        NotifyKind.messages => notifyMessages,
      };

  Settings copyWith({
    int? intervalSeconds,
    int? delayHours,
    bool? visible,
    bool? locationEnabled,
    bool? notifyMatches,
    bool? notifyLikes,
    bool? notifyMessages,
  }) =>
      Settings(
        intervalSeconds: intervalSeconds ?? this.intervalSeconds,
        delayHours: delayHours ?? this.delayHours,
        visible: visible ?? this.visible,
        locationEnabled: locationEnabled ?? this.locationEnabled,
        notifyMatches: notifyMatches ?? this.notifyMatches,
        notifyLikes: notifyLikes ?? this.notifyLikes,
        notifyMessages: notifyMessages ?? this.notifyMessages,
      );

  Settings withNotify(NotifyKind kind, bool value) => switch (kind) {
        NotifyKind.matches => copyWith(notifyMatches: value),
        NotifyKind.likes => copyWith(notifyLikes: value),
        NotifyKind.messages => copyWith(notifyMessages: value),
      };
}
