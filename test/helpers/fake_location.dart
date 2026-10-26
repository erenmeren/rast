import 'dart:async';

import 'package:rast/data/repositories.dart';

class FakeLocation implements LocationRepository {
  bool permitted = true;
  bool offline = false;
  final uploads = <List<LocationSample>>[];
  final controllers = <StreamController<Fix>>[];
  int streamsStarted = 0;
  int? lastInterval;

  @override
  Future<bool> hasPermissions() async => permitted;
  @override
  Future<bool> requestPermissions() async => permitted;

  @override
  Stream<Fix> fixes(int intervalSeconds) {
    streamsStarted++;
    lastInterval = intervalSeconds;
    final c = StreamController<Fix>();
    controllers.add(c);
    return c.stream;
  }

  @override
  Future<String> deviceId() async => 'dev-1';

  @override
  Future<List<String>> upload(List<LocationSample> samples) async {
    if (offline) throw Exception('offline');
    uploads.add(samples);
    return [for (final s in samples) s.id];
  }

  void emit(Fix fix) => controllers.last.add(fix);
  void fail(Object error) => controllers.last.addError(error);
}
