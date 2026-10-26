import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/models/models.dart';
import '../repositories.dart';
import 'ids.dart';
import 'profile_repository.dart' show storagePrefix;

/// A server card as the app's [Person]. Nothing about time or distance.
Person personFromCard(Map<String, dynamic> card) {
  final photos = [for (final p in (card['photos'] as List? ?? const [])) '$storagePrefix$p'];
  final gender = card['gender'] as String?;
  return Person(
    id: card['account_id'] as String,
    age: card['age'] as int,
    gender: gender == null ? null : Gender.values.where((g) => g.name == gender).firstOrNull,
    customGender: (card['custom_gender'] as String?) ?? '',
    photo: photos.isEmpty ? '' : photos.first,
    photos: photos,
  );
}

class SupabaseDiscoveryRepository implements DiscoveryRepository {
  SupabaseDiscoveryRepository(this.client);
  final SupabaseClient client;

  Future<Map<String, dynamic>> _rpc(String fn, [Map<String, dynamic>? params]) async =>
      (await client.rpc(fn, params: params) as Map).cast<String, dynamic>();

  @override
  Future<String> startSession() async => (await _rpc('start_discovery_session'))['session_id'] as String;

  @override
  Future<CardPage> cards(String sessionId, {String? after}) async {
    final r = await _rpc('discovery_cards', {'session_id': sessionId, 'after': after, 'page_size': 20});
    if (r['outcome'] != 'ok') return const CardPage([], null);
    return CardPage([for (final c in r['cards'] as List) personFromCard((c as Map).cast())], r['next'] as String?);
  }

  @override
  Future<LikeOutcome> like(String id) async {
    final r = await _rpc('like_account', {'target': id, 'client_op_id': _opId()});
    return switch (r['outcome']) { 'matched' => LikeOutcome.matched, 'liked' => LikeOutcome.liked, _ => LikeOutcome.unavailable };
  }

  @override
  Future<bool> pass(String id) async =>
      (await _rpc('pass_account', {'target': id, 'client_op_id': _opId()}))['outcome'] == 'passed';

  @override
  Future<String?> rewind() async {
    final r = await _rpc('rewind_pass');
    return r['outcome'] == 'restored' ? r['account_id'] as String : null;
  }

  @override
  Future<LikesYouResult> likesYou() async {
    final r = await _rpc('likes_you');
    return LikesYouResult(
      premium: r['premium'] == true,
      count: r['count'] as int,
      previews: [for (final p in (r['previews'] as List? ?? const [])) LikePreview(p['token'] as String, p['age'] as int)],
      cards: [for (final c in (r['cards'] as List? ?? const [])) personFromCard((c as Map).cast())],
    );
  }

  @override
  Future<List<Connection>> connections() async {
    final r = await _rpc('connections');
    return [
      for (final c in (r['connections'] as List? ?? const []))
        Connection(pairId: c['pair_id'] as String, revision: c['revision'] as int, person: personFromCard((c['card'] as Map).cast())),
    ];
  }

  @override
  Future<Person?> personCard(String id) async {
    final r = await _rpc('person_card', {'target': id});
    return r['outcome'] == 'ok' ? personFromCard((r['card'] as Map).cast()) : null;
  }

  static String _opId() => newUuid();
}
