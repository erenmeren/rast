import 'dart:async';

import 'package:rast/data/repositories.dart';

class FakePush implements PushRepository {
  bool permitted = true;
  int permissionRequests = 0;
  final registered = <String>[];
  bool unregistered = false;
  /// Shared with other fakes to pin call order.
  final log = <String>[];
  final tokenController = StreamController<String>.broadcast();
  final tapController = StreamController<PushTap>.broadcast();

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return permitted;
  }

  @override
  Stream<String> tokens() => tokenController.stream;
  @override
  Future<void> register(String token) async => registered.add(token);
  @override
  Future<void> unregister() async {
    unregistered = true;
    log.add('unregister');
  }
  @override
  Stream<PushTap> taps() => tapController.stream;
}
