// Live tests talk to the real Supabase project as the test user. They are
// skipped unless run with `--dart-define=RAST_LIVE=true`:
//   flutter test test/live --dart-define=RAST_LIVE=true --timeout 120s
import 'package:rast/data/supabase/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

const bool live = bool.fromEnvironment('RAST_LIVE');
const String testPhone = '+905550000001';
const String testOtp = '111111';

/// A client signed in as the test user (fixed OTP, no SMS is sent). Auth
/// allows one OTP request per number every few seconds, so test files that
/// run back to back wait their turn.
Future<SupabaseClient> liveClient() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  for (var attempt = 0;; attempt++) {
    try {
      await client.auth.signInWithOtp(phone: testPhone);
      break;
    } on AuthApiException catch (e) {
      if (e.code != 'over_sms_send_rate_limit' || attempt >= 5) rethrow;
      await Future<void>.delayed(const Duration(seconds: 6));
    }
  }
  await client.auth.verifyOTP(phone: testPhone, token: testOtp, type: OtpType.sms);
  return client;
}
