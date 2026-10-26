import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Project coordinates. The publishable key is public by design; every
/// access rule lives in the database (RLS) and the RPCs.
const String supabaseUrl = 'https://tmgpzujqdninoavcalto.supabase.co';
const String supabaseAnonKey = 'sb_publishable_46eF54dUnAcN3geSXMhY-w_QNOj-0C_';

/// The one client the production adapters share.
class Backend {
  Backend(this.client);
  final SupabaseClient client;

  static Future<Backend> init() async {
    await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
    return Backend(Supabase.instance.client);
  }

  String get functionsUrl => '$supabaseUrl/functions/v1';
  String? get accessToken => client.auth.currentSession?.accessToken;
  String? get userId => client.auth.currentUser?.id;
}

/// Overridden by bootstrap when the Supabase backend is selected.
final backendProvider = Provider<Backend>((ref) => throw StateError('backendProvider is only set by bootstrap'));
