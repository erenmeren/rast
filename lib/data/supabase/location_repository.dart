import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/storage/preferences_store.dart';
import '../repositories.dart';

const String deviceKey = 'rast.device.id';

/// The device row of this install, created once and remembered in the store.
/// Shared by location upload and push registration.
Future<String> ensureDeviceId(SupabaseClient client, PreferencesStore store) async {
  final stored = store.getString(deviceKey);
  if (stored != null) return stored;
  final me = client.auth.currentUser?.id;
  if (me == null) throw const AuthException('not signed in');
  final row = await client.from('device').insert({'account_id': me, 'platform': Platform.operatingSystem}).select('id').single();
  final id = row['id'] as String;
  await store.setString(deviceKey, id);
  return id;
}

/// geolocator with a foreground service (as proven in the location lab),
/// one device row per install, batches into submit_location_samples.
class SupabaseLocationRepository implements LocationRepository {
  SupabaseLocationRepository(this.client, this.store);
  final SupabaseClient client;
  final PreferencesStore store;

  @override
  Future<bool> hasPermissions() async {
    if (!(await Permission.location.status).isGranted) return false;
    if (await Geolocator.getLocationAccuracy() != LocationAccuracyStatus.precise) return false;
    if (!(await Permission.locationAlways.status).isGranted) return false;
    return Platform.isAndroid ? (await Permission.notification.status).isGranted : true;
  }

  /// Android needs the order fine → background → notifications.
  @override
  Future<bool> requestPermissions() async {
    if (!(await Permission.location.request()).isGranted) return false;
    if (await Geolocator.getLocationAccuracy() != LocationAccuracyStatus.precise) return false;
    if (!(await Permission.locationAlways.request()).isGranted) return false;
    if (Platform.isAndroid && !(await Permission.notification.request()).isGranted) return false;
    return true;
  }

  @override
  Stream<Fix> fixes(int intervalSeconds) {
    final LocationSettings settings;
    if (Platform.isAndroid) {
      settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        intervalDuration: Duration(seconds: intervalSeconds),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'rast',
          notificationText: 'Finding crossings nearby',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    } else if (Platform.isIOS) {
      settings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    } else {
      settings = const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0);
    }
    return Geolocator.getPositionStream(locationSettings: settings).map((p) => Fix(
          lat: p.latitude,
          lon: p.longitude,
          accuracyM: p.accuracy,
          observedAt: p.timestamp.toUtc(),
        ));
  }

  @override
  Future<String> deviceId() => ensureDeviceId(client, store);

  @override
  Future<List<String>> upload(List<LocationSample> samples) async {
    final r = (await client.rpc('submit_location_samples', params: {'samples': [for (final s in samples) s.toJson()]}) as Map);
    final accepted = (r['accepted'] as List? ?? const []).cast<String>();
    // a rejected sample (too old, inaccurate, malformed) is not worth a retry
    final rejected = [for (final x in (r['rejected'] as List? ?? const [])) x['id'] as String];
    return [...accepted, ...rejected];
  }
}
