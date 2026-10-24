import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'lab_store.dart';
import 'permissions.dart';
import 'platform.dart';
import 'sampler.dart';

final documentsDirProvider = FutureProvider<Directory>((_) => getApplicationDocumentsDirectory());

final labStoreProvider = FutureProvider<LabStore>((ref) async {
  final dir = await ref.watch(documentsDirProvider.future);
  return LabStore.open('${dir.path}/lab.db');
});

/// Installation id, generated once and kept in a file next to the database.
final deviceIdProvider = FutureProvider<String>((ref) async {
  final dir = await ref.watch(documentsDirProvider.future);
  final file = File('${dir.path}/device_id');
  if (await file.exists()) return (await file.readAsString()).trim();
  final id = const Uuid().v4();
  await file.writeAsString(id);
  return id;
});

final samplerProvider = FutureProvider<Sampler>((ref) async {
  final store = await ref.watch(labStoreProvider.future);
  final deviceId = await ref.watch(deviceIdProvider.future);
  final sampler = Sampler(
    store: store,
    positions: geolocatorStream,
    battery: readBattery,
    now: () => DateTime.now().toUtc(),
    newSession: (config) => buildSession(config, deviceId: deviceId),
  );
  ref.onDispose(sampler.dispose);
  return sampler;
});

final permissionFlowProvider =
    Provider<PermissionFlow>((_) => PermissionFlow(PermissionHandlerGateway()));
