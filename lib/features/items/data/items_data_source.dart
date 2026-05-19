import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Thin Supabase wrapper around the `items` table.
///
/// Intentionally has no business logic — every method is a one-liner
/// pass-through to the Supabase client. Tests mock this interface so
/// the repository above it can be unit-tested without fighting
/// Supabase's fluent builder chain.
///
/// All methods rely on RLS for ownership enforcement; the repository
/// is responsible for setting `owner_id` correctly at insert time.
abstract interface class ItemsDataSource {
  /// Active items owned by [ownerId], sorted by target_date ascending.
  /// The RLS `items_select_own` policy will silently filter out any row
  /// not owned by the authenticated user even if [ownerId] is wrong.
  Future<List<Map<String, dynamic>>> selectActive(String ownerId);

  /// Single row by id (any status). Throws if Postgres-level error;
  /// returns null if no row.
  Future<Map<String, dynamic>?> selectById(String id);

  /// Insert and return the inserted row.
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload);

  /// Patch by id and return the updated row. The DB's
  /// `items_touch_updated_at` trigger refreshes `updated_at`.
  Future<Map<String, dynamic>> updateById(
    String id,
    Map<String, dynamic> patch,
  );
}

/// Production [ItemsDataSource] backed by Supabase.
///
/// Each method is one fluent call to the Supabase client. This file is
/// covered by manual smoke (Task 19) + Playwright runtime checks rather
/// than unit tests, because mocking the Supabase fluent chain is
/// fragile (each `.eq()`/`.order()` returns a differently-typed builder
/// that also implements Future).
class SupabaseItemsDataSource implements ItemsDataSource {
  SupabaseItemsDataSource(this._client);

  final sb.SupabaseClient _client;
  static const _table = 'items';

  @override
  Future<List<Map<String, dynamic>>> selectActive(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .eq('status', 'active')
        .order('target_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>?> selectById(String id) async {
    final row = await _client.from(_table).select().eq('id', id).maybeSingle();
    return row;
  }

  @override
  Future<Map<String, dynamic>> insert(Map<String, dynamic> payload) async {
    final row = await _client.from(_table).insert(payload).select().single();
    return row;
  }

  @override
  Future<Map<String, dynamic>> updateById(
    String id,
    Map<String, dynamic> patch,
  ) async {
    final row = await _client
        .from(_table)
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    return row;
  }
}
