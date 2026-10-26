import 'package:rast/core/models/models.dart';
import 'package:rast/data/repositories.dart';

class FakeSafety implements SafetyRepository {
  bool offline = false;
  final log = <String>[];
  SafetyState remote = SafetyState.empty;

  Future<void> _op(String name) async {
    log.add(name);
    if (offline) throw Exception('offline');
  }

  @override
  Future<SafetyState> load() async => remote;
  @override
  Future<void> block(String id) => _op('block $id');
  @override
  Future<void> unblock(String id) => _op('unblock $id');
  @override
  Future<void> disconnect(String id) => _op('disconnect $id');
  @override
  Future<void> report(String id, String reason, {required bool alsoBlock}) => _op('report $id');
  @override
  Future<List<Person>> blockedPeople() async => const [];
  @override
  Future<void> deleteAccount() => _op('delete');
  @override
  Future<void> clear() async {}
}
