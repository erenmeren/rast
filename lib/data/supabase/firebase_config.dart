import 'package:firebase_core/firebase_core.dart';

/// Firebase client coordinates, passed with
/// `--dart-define-from-file=firebase.env.json`. Public values like the
/// Supabase publishable key. All four empty: no Firebase, no push.
abstract final class FirebaseConfig {
  static const apiKey = String.fromEnvironment('RAST_FCM_API_KEY');
  static const appId = String.fromEnvironment('RAST_FCM_APP_ID');
  static const senderId = String.fromEnvironment('RAST_FCM_SENDER_ID');
  static const projectId = String.fromEnvironment('RAST_FCM_PROJECT_ID');

  static bool get present => apiKey.isNotEmpty && appId.isNotEmpty && senderId.isNotEmpty && projectId.isNotEmpty;

  static FirebaseOptions get options => const FirebaseOptions(apiKey: apiKey, appId: appId, messagingSenderId: senderId, projectId: projectId);
}
