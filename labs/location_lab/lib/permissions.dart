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

class PermissionHandlerGateway implements PermissionGateway {
  Permission _of(PermissionItem item) => switch (item) {
        PermissionItem.fineLocation => Permission.location,
        PermissionItem.backgroundLocation => Permission.locationAlways,
        PermissionItem.notifications => Permission.notification,
      };

  @override
  Future<bool> isGranted(PermissionItem item) async =>
      (await _of(item).status).isGranted;

  @override
  Future<bool> request(PermissionItem item) async =>
      (await _of(item).request()).isGranted;
}
