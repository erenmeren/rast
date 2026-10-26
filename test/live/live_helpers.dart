// Live tests talk to the real Supabase project as the test user. They are
// skipped unless run with `--dart-define=RAST_LIVE=true`:
//   flutter test test/live --dart-define=RAST_LIVE=true --timeout 120s
import 'package:rast/data/supabase/backend.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

const bool live = bool.fromEnvironment('RAST_LIVE');
const String testPhone = '+905550000001';
const String testOtp = '111111';

/// A client signed in as the test user (fixed OTP, no SMS is sent).
Future<SupabaseClient> liveClient() async {
  final client = SupabaseClient(supabaseUrl, supabaseAnonKey);
  await client.auth.signInWithOtp(phone: testPhone);
  await client.auth.verifyOTP(phone: testPhone, token: testOtp, type: OtpType.sms);
  return client;
}
