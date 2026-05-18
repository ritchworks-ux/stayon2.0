import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/app_user.dart';
import '../../../core/services/supabase_service.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({sb.SupabaseClient? client})
    : _client = client ?? SupabaseService.client;

  final sb.SupabaseClient _client;

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> currentUserChanges() async* {
    yield currentUser;
    yield* _client.auth.onAuthStateChange.map(
      (event) => _toAppUser(event.session?.user),
    );
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthException(e.code ?? 'sign_up_failed', e.message);
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthException(e.code ?? 'sign_in_failed', e.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AppUser? _toAppUser(sb.User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }
}
