import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import '../../core/models/models.dart';
import '../repositories.dart';

/// Phone OTP through Supabase Auth (Twilio Verify behind it).
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this.client);
  final SupabaseClient client;
  String _phone = '';

  /// E.164: the dial code plus digits only.
  static String e164(String dial, String phone) => dial + phone.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  Future<void> sendCode(String dial, String phone) async {
    _phone = e164(dial, phone);
    await client.auth.signInWithOtp(phone: _phone);
  }

  @override
  Future<bool> verify(String code) async {
    try {
      final res = await client.auth.verifyOTP(phone: _phone, token: code.trim(), type: OtpType.sms);
      return res.session != null;
    } on AuthException {
      return false;
    }
  }

  @override
  Future<void> signOut() => client.auth.signOut();
}

/// The local phase store, gated by the real session: no Supabase session
/// means signed out, whatever the device remembers.
class SupabaseSessionRepository implements SessionRepository {
  SupabaseSessionRepository(this.client, this.inner);
  final SupabaseClient client;
  final SessionRepository inner;

  @override
  Session load() {
    if (client.auth.currentSession == null) return Session.signedOut;
    return inner.load().copyWith(verified: true);
  }

  @override
  Future<void> save(Session session) => inner.save(session);

  @override
  Future<void> clear() => inner.clear();
}
