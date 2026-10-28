import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/storage/preferences_store.dart';
import '../repositories.dart';
import 'location_repository.dart' show ensureDeviceId;

/// firebase_messaging; the token lives on this install's device row so the
/// push-send function finds it.
class SupabasePushRepository implements PushRepository {
  SupabasePushRepository(this.client, this.store);
  final SupabaseClient client;
  final PreferencesStore store;

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final s = (await _fcm.requestPermission()).authorizationStatus;
    return s == AuthorizationStatus.authorized || s == AuthorizationStatus.provisional;
  }

  // firebase_messaging 17 deprecates the token API for an installation-id
  // flow; push-send targets `message.token`, which FCM v1 still serves.
  @override
  Stream<String> tokens() async* {
    // ignore: deprecated_member_use
    final current = await _fcm.getToken();
    if (current != null) yield current;
    // ignore: deprecated_member_use
    yield* _fcm.onTokenRefresh;
  }

  Future<void> _write(String? token) async {
    final id = await ensureDeviceId(client, store);
    await client.from('device').update({'push_token': token}).eq('id', id);
  }

  @override
  Future<void> register(String token) => _write(token);

  @override
  Future<void> unregister() async {
    try {
      await _write(null);
    } catch (_) {
      // already signed out: the row is cleared on the next sign-in's register
    }
    // ignore: deprecated_member_use
    await _fcm.deleteToken();
  }

  @override
  Stream<PushTap> taps() async* {
    final initial = await _fcm.getInitialMessage();
    if (initial != null) yield* Stream.fromIterable(_tap(initial));
    await for (final m in FirebaseMessaging.onMessageOpenedApp) {
      yield* Stream.fromIterable(_tap(m));
    }
  }

  List<PushTap> _tap(RemoteMessage m) {
    final kind = m.data['kind'];
    if (kind is! String) return const [];
    return [PushTap(kind: kind, accountId: m.data['account_id'] as String?)];
  }
}
