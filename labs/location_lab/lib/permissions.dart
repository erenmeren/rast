import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

enum PermissionItem { fineLocation, backgroundLocation, notifications }

class PermissionSnapshot {
  const PermissionSnapshot(this.granted);

  final Map<PermissionItem, bool> granted;

  bool get allGranted => PermissionItem.values.every((i) => granted[i] == true);

  List<PermissionItem> get missing =>
      PermissionItem.values.where((i) => granted[i] != true).toList();
}

abstract class PermissionGateway {
  Future<bool> isGranted(PermissionItem item);
  Future<bool> request(PermissionItem item);
}

/// Requests permissions in the order Android requires: fine location first,
/// then background ("Allow all the time"), then notifications.
class PermissionFlow {
  PermissionFlow(this._gateway);

  final PermissionGateway _gateway;

  Future<PermissionSnapshot> snapshot() async => PermissionSnapshot({
        for (final item in PermissionItem.values) item: await _gateway.isGranted(item),
      });

  Future<PermissionItem?> requestNextMissing() async {
    for (final item in PermissionItem.values) {
      if (!await _gateway.isGranted(item)) {
        await _gateway.request(item);
        return item;
      }
    }
    return null;
  }
}

/// Gateway over permission_handler and geolocator. The three platform calls are
/// injectable so the precise-location rule can be tested without a device.
class PermissionHandlerGateway implements PermissionGateway {
  PermissionHandlerGateway({
    Future<bool> Function(Permission)? status,
    Future<bool> Function(Permission)? request,
    Future<bool> Function()? precise,
  })  : _status = status ?? ((p) async => (await p.status).isGranted),
        _request = request ?? ((p) async => (await p.request()).isGranted),
        _precise = precise ??
            (() async => await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.precise);

  final Future<bool> Function(Permission) _status;
  final Future<bool> Function(Permission) _request;
  final Future<bool> Function() _precise;

  Permission _of(PermissionItem item) => switch (item) {
        PermissionItem.fineLocation => Permission.location,
        PermissionItem.backgroundLocation => Permission.locationAlways,
        PermissionItem.notifications => Permission.notification,
      };

  /// Fine location counts only when the OS will deliver precise fixes; an
  /// "approximate" grant shows as granted to permission_handler but would
  /// waste a whole run.
  @override
  Future<bool> isGranted(PermissionItem item) async {
    final granted = await _status(_of(item));
    if (item == PermissionItem.fineLocation && granted) return _precise();
    return granted;
  }

  @override
  Future<bool> request(PermissionItem item) async {
    final granted = await _request(_of(item));
    if (item == PermissionItem.fineLocation && granted) return _precise();
    return granted;
  }
}
