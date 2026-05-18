/// Build-time configuration read from --dart-define values.
/// Missing values throw at startup so we never run with a misconfigured backend.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Throws [StateError] if any required value is empty.
  static void assertValid() {
    if (supabaseUrl.isEmpty) {
      throw StateError(
        'SUPABASE_URL is not set. '
        'Run with --dart-define-from-file=.env.local',
      );
    }
    if (supabasePublishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_PUBLISHABLE_KEY is not set. '
        'Run with --dart-define-from-file=.env.local',
      );
    }
  }
}
