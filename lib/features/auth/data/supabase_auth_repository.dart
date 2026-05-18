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
    await for (final event in _client.auth.onAuthStateChange) {
      final user = event.session?.user;
      if (user != null && event.event == sb.AuthChangeEvent.signedIn) {
        await _ensureProfile(user);
      }
      yield _toAppUser(user);
    }
  }

  /// Idempotent upsert. RLS lets the user write only their own row.
  Future<void> _ensureProfile(sb.User user) async {
    await _client
        .from('profiles')
        .upsert(
          {'id': user.id, 'display_name': user.userMetadata?['display_name']},
          onConflict: 'id',
          ignoreDuplicates: true,
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
