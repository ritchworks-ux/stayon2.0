import '../../../core/models/app_user.dart';

/// Repository contract for authentication operations.
/// All async ops throw on failure (no Result wrapper — controllers translate).
abstract interface class AuthRepository {
  /// Emits the current user, or null after sign-out.
  /// Emits immediately with current cached value on subscribe.
  Stream<AppUser?> currentUserChanges();

  /// Synchronous read of the current user (may be null).
  AppUser? get currentUser;

  /// Throws [AuthException] on failure (e.g. duplicate email).
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Throws [AuthException] on failure (e.g. invalid credentials).
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

/// Thrown by [AuthRepository] for any user-actionable failure.
/// UI maps [code] to a friendly message.
class AuthException implements Exception {
  AuthException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code): $message';
}
