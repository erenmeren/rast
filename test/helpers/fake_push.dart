import 'dart:async';

import 'package:rast/data/repositories.dart';

class FakePush implements PushRepository {
  bool permitted = true;
  int permissionRequests = 0;
  final registered = <String>[];
  bool unregistered = false;
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
  Future<void> unregister() async => unregistered = true;
  @override
  Stream<PushTap> taps() => tapController.stream;
}
