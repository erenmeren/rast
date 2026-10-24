import 'package:flutter_test/flutter_test.dart';
import 'package:location_lab/permissions.dart';

class FakeGateway implements PermissionGateway {
  FakeGateway(this.granted);

  final Set<PermissionItem> granted;
  final requested = <PermissionItem>[];

  @override
  Future<bool> isGranted(PermissionItem item) async => granted.contains(item);

  @override
  Future<bool> request(PermissionItem item) async {
    requested.add(item);
    granted.add(item);
    return true;
  }
}

void main() {
  test('requests fine before background before notifications', () async {
    final gateway = FakeGateway({});
    final flow = PermissionFlow(gateway);

    expect(await flow.requestNextMissing(), PermissionItem.fineLocation);
    expect(await flow.requestNextMissing(), PermissionItem.backgroundLocation);
    expect(await flow.requestNextMissing(), PermissionItem.notifications);
    expect(gateway.requested, [
      PermissionItem.fineLocation,
      PermissionItem.backgroundLocation,
      PermissionItem.notifications,
    ]);
  });

  test('returns null when everything is granted', () async {
    final gateway = FakeGateway({...PermissionItem.values});
    final flow = PermissionFlow(gateway);
    expect(await flow.requestNextMissing(), isNull);
    expect(gateway.requested, isEmpty);
    final snap = await flow.snapshot();
    expect(snap.allGranted, isTrue);
    expect(snap.granted[PermissionItem.backgroundLocation], isTrue);
  });

  test('snapshot reports the missing item', () async {
    final flow = PermissionFlow(FakeGateway({PermissionItem.fineLocation}));
    final snap = await flow.snapshot();
    expect(snap.allGranted, isFalse);
    expect(snap.missing, [PermissionItem.backgroundLocation, PermissionItem.notifications]);
  });
}
