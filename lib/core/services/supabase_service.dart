import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Thin wrapper that owns Supabase initialization.
/// Call [SupabaseService.init] exactly once before runApp.
abstract final class SupabaseService {
  static Future<void> init() async {
    Env.assertValid();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      // Param is named `anonKey` in supabase_flutter; the new "publishable"
      // key from the Supabase dashboard fills the same role.
      anonKey: Env.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Global client. Safe to call from anywhere after [init].
  static SupabaseClient get client => Supabase.instance.client;
}
