import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/models/models.dart';
import '../repositories.dart';
import '../../core/ids.dart';

/// Every operation is an RPC with the server's own idempotency; `load` reads
/// the member's block, report and pair rows back through RLS.
class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this.client);
  final SupabaseClient client;

  @override
  Future<SafetyState> load() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return SafetyState.empty;
    final results = await Future.wait<dynamic>([
      client.from('block').select('blocked'),
      client.from('pair').select('a, b').not('disconnected_at', 'is', null),
      client.from('report').select('target, reason_code'),
    ]);
    final blocked = {for (final r in results[0] as List) r['blocked'] as String};
    final disconnected = {for (final p in results[1] as List) (p['a'] == me ? p['b'] : p['a']) as String};
    final reports = [
      for (final r in results[2] as List)
        if (reportReasons.contains(r['reason_code'])) Report(personId: r['target'] as String, reason: r['reason_code'] as String),
    ];
    return SafetyState(blocked: blocked, disconnected: disconnected, reports: reports);
  }

  @override
  Future<void> block(String id) => client.rpc('block_account', params: {'target': id});

  @override
  Future<void> unblock(String id) => client.rpc('unblock_account', params: {'target': id});

  @override
  Future<void> disconnect(String id) => client.rpc('disconnect_pair', params: {'target': id, 'client_op_id': newUuid()});

  @override
  Future<void> report(String id, String reason, {required bool alsoBlock}) =>
      client.rpc('submit_report', params: {'target': id, 'reason_code': reason, 'client_op_id': newUuid(), 'also_block': alsoBlock});

  /// Blocked and removed people keep only an age: their photos are not viewable.
  @override
  Future<List<Person>> hiddenPeople() async {
    final results = await Future.wait<dynamic>([client.rpc('blocked_accounts'), client.rpc('disconnected_accounts')]);
    final rows = [
      ...((results[0] as Map)['blocked'] as List? ?? const []),
      ...((results[1] as Map)['disconnected'] as List? ?? const []),
    ];
    return [for (final b in rows) Person(id: b['account_id'] as String, age: b['age'] as int, gender: null, photo: '')];
  }

  @override
  Future<void> deleteAccount() => client.rpc('delete_account');

  @override
  Future<void> clear() async {}
}
