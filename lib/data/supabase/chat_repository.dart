import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/models/models.dart';
import '../../core/storage/preferences_store.dart';
import '../repositories.dart';
import 'discovery_repository.dart' show personFromCard;

/// Threads from the open matches (`connections()`) and the message rows RLS
/// lets the member read. Unread counts come from a local "read up to seq"
/// per thread; nothing about reading is sent to the server.
class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this.client, this.store);
  final SupabaseClient client;
  final PreferencesStore store;
  final Map<String, int> _lastSeq = {};

  static String _readKey(String threadId) => 'rast.read.$threadId';

  @override
  Future<ChatSnapshot> load() async {
    final me = client.auth.currentUser?.id;
    if (me == null) return const ChatSnapshot([], []);
    final results = await Future.wait<dynamic>([
      client.rpc('connections'),
      client.from('message').select('pair_id, sender, seq, body, created_at').order('pair_id', ascending: true).order('seq', ascending: true),
    ]);
    final connections = ((results[0] as Map)['connections'] as List? ?? const []);
    final messages = (results[1] as List).cast<Map<String, dynamic>>();
    final byPair = <String, List<Map<String, dynamic>>>{};
    for (final m in messages) {
      byPair.putIfAbsent(m['pair_id'] as String, () => []).add(m);
    }
    final threads = <Thread>[];
    final people = <Person>[];
    for (final c in connections) {
      final person = personFromCard((c['card'] as Map).cast());
      people.add(person);
      final rows = byPair[c['pair_id'] as String] ?? const [];
      final readUpTo = store.getInt(_readKey(person.id)) ?? 0;
      final lastSeq = rows.isEmpty ? 0 : rows.last['seq'] as int;
      _lastSeq[person.id] = lastSeq;
      threads.add(Thread(
        id: person.id,
        personId: person.id,
        unread: rows.where((m) => m['sender'] != me && (m['seq'] as int) > readUpTo).length,
        messages: [
          for (final m in rows)
            Message(text: m['body'] as String, own: m['sender'] == me, time: _hhmm(DateTime.parse(m['created_at'] as String).toLocal())),
        ],
      ));
    }
    return ChatSnapshot(threads, people);
  }

  static String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Future<int?> send(String targetId, String clientOpId, String body) async {
    final r = (await client.rpc('send_message', params: {'target': targetId, 'client_op_id': clientOpId, 'body': body}) as Map);
    if (r['outcome'] != 'sent') return null;
    final seq = r['seq'] as int;
    _lastSeq[targetId] = seq;
    await store.setInt(_readKey(targetId), seq);
    return seq;
  }

  @override
  Stream<void> changes() {
    final controller = StreamController<void>.broadcast();
    RealtimeChannel? channel;
    controller.onListen = () {
      channel = client
          .channel('pair-events-${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'pair_event',
            callback: (_) => controller.add(null),
          )
          .subscribe();
    };
    controller.onCancel = () async {
      final ch = channel;
      channel = null;
      if (ch != null) await client.removeChannel(ch);
    };
    return controller.stream;
  }

  @override
  Future<void> markRead(String threadId) => store.setInt(_readKey(threadId), _lastSeq[threadId] ?? 0);
}
