import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ntp/ntp.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'sampler.dart';

const labVersion = '0.1.0';

LocationAccuracy _accuracy(RequestedAccuracy a) => switch (a) {
      RequestedAccuracy.best => LocationAccuracy.best,
      RequestedAccuracy.high => LocationAccuracy.high,
      RequestedAccuracy.medium => LocationAccuracy.medium,
    };

/// Position stream configured for background sampling on each platform.
Stream<Position> geolocatorStream(int intervalS, RequestedAccuracy accuracy) {
  final LocationSettings settings;
  if (Platform.isAndroid) {
    settings = AndroidSettings(
      accuracy: _accuracy(accuracy),
      distanceFilter: 0,
      intervalDuration: Duration(seconds: intervalS),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'rast location lab',
        notificationText: 'Recording location samples',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  } else if (Platform.isIOS) {
    settings = AppleSettings(
      accuracy: _accuracy(accuracy),
      activityType: ActivityType.other,
      distanceFilter: 0,
      pauseLocationUpdatesAutomatically: false,
      showBackgroundLocationIndicator: true,
      allowBackgroundLocationUpdates: true,
    );
  } else {
    settings = LocationSettings(accuracy: _accuracy(accuracy), distanceFilter: 0);
  }
  return Geolocator.getPositionStream(locationSettings: settings);
}

Future<(int, BatteryStateLabel)> readBattery() async {
  final battery = Battery();
  final pct = await battery.batteryLevel;
  final state = switch (await battery.batteryState) {
    BatteryState.charging => BatteryStateLabel.charging,
    BatteryState.discharging => BatteryStateLabel.discharging,
    BatteryState.full => BatteryStateLabel.full,
    BatteryState.connectedNotCharging => BatteryStateLabel.charging,
    BatteryState.unknown => BatteryStateLabel.unknown,
  };
  return (pct, state);
}

Future<(String model, String os)> deviceDescription() async {
  final info = DeviceInfoPlugin();
  if (Platform.isAndroid) {
    final a = await info.androidInfo;
    return (a.model, 'Android ${a.version.release} (SDK ${a.version.sdkInt})');
  }
  if (Platform.isIOS) {
    final i = await info.iosInfo;
    return (i.utsname.machine, 'iOS ${i.systemVersion}');
  }
  return (Platform.operatingSystem, Platform.operatingSystemVersion);
}

/// NTP minus device clock in milliseconds, or null when offline.
Future<int?> ntpOffsetMs() async {
  try {
    return await NTP.getNtpOffset(timeout: const Duration(seconds: 3));
  } catch (_) {
    return null;
  }
}

Future<LabSession> buildSession(SamplerConfig config, {required String deviceId}) async {
  final (model, os) = await deviceDescription();
  return LabSession(
    id: const Uuid().v4(),
    deviceId: deviceId,
    deviceModel: model,
    osVersion: os,
    appVersion: labVersion,
    startedAtUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
    requestedIntervalS: config.intervalS,
    requestedAccuracy: config.accuracy,
    ntpOffsetMs: await ntpOffsetMs(),
  );
}
