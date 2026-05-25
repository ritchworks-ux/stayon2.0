import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Thin Supabase wrapper around the `attachments` and `storage_quotas` tables.
///
/// Intentionally has no business logic — every method is a one-liner
/// pass-through to the Supabase client. Tests mock this interface so
/// the repository above it can be unit-tested without fighting
/// Supabase's fluent builder chain.
///
/// All methods rely on RLS for ownership enforcement; the repository
/// is responsible for validating ownership and quotas before calling
/// methods that modify data.
abstract interface class AttachmentDataSource {
  /// Retrieve storage quota for the given owner.
  ///
  /// Returns a map with keys: owner_id, tier, total_bytes_used,
  /// quota_limit_bytes, attachment_count, attachment_limit.
  ///
  /// Returns null if no quota record exists (shouldn't happen with
  /// proper migrations, but handled gracefully).
  Future<Map<String, dynamic>?> getQuotaForOwner(String ownerId);

  /// Insert attachment metadata and return the inserted row.
  Future<Map<String, dynamic>> insertAttachment(Map<String, dynamic> payload);

  /// Retrieve all attachments for the given item.
  ///
  /// RLS `attachments_select_own` policy will silently filter out rows
  /// not owned by the authenticated user.
  Future<List<Map<String, dynamic>>> selectByItemId(String itemId);

  /// Retrieve all attachments owned by the given user.
  ///
  /// RLS `attachments_select_own` policy will silently filter out rows
  /// not owned by the authenticated user even if [ownerId] is wrong.
  Future<List<Map<String, dynamic>>> selectByOwnerId(String ownerId);

  /// Retrieve a single attachment by id.
  ///
  /// Returns null if no row found or RLS denies access.
  Future<Map<String, dynamic>?> selectById(String attachmentId);

  /// Delete attachment by id.
  /// RLS `attachments_delete_own` will reject if caller doesn't own it.
  Future<void> deleteAttachment(String attachmentId);

  /// Update attachment metadata and return the updated row.
  /// RLS `attachments_update_own` will reject if caller doesn't own it.
  Future<Map<String, dynamic>> updateAttachment(
    String attachmentId,
    Map<String, dynamic> patch,
  );
}

/// Production [AttachmentDataSource] backed by Supabase.
///
/// Each method is one fluent call to the Supabase client. This file is
/// covered by manual smoke tests rather than unit tests, because mocking
/// the Supabase fluent chain is fragile.
class SupabaseAttachmentDataSource implements AttachmentDataSource {
  SupabaseAttachmentDataSource(this._client);

  final sb.SupabaseClient _client;
  static const _attachmentsTable = 'attachments';
  static const _quotasTable = 'storage_quotas';

  @override
  Future<Map<String, dynamic>?> getQuotaForOwner(String ownerId) async {
    final row = await _client
        .from(_quotasTable)
        .select()
        .eq('owner_id', ownerId)
        .maybeSingle();
    return row;
  }

  @override
  Future<Map<String, dynamic>> insertAttachment(
    Map<String, dynamic> payload,
  ) async {
    final row = await _client
        .from(_attachmentsTable)
        .insert(payload)
        .select()
        .single();
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> selectByItemId(String itemId) async {
    final rows = await _client
        .from(_attachmentsTable)
        .select()
        .eq('item_id', itemId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>> selectByOwnerId(String ownerId) async {
    final rows = await _client
        .from(_attachmentsTable)
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  @override
  Future<Map<String, dynamic>?> selectById(String attachmentId) async {
    final row = await _client
        .from(_attachmentsTable)
        .select()
        .eq('id', attachmentId)
        .maybeSingle();
    return row;
  }

  @override
  Future<void> deleteAttachment(String attachmentId) async {
    await _client.from(_attachmentsTable).delete().eq('id', attachmentId);
  }

  @override
  Future<Map<String, dynamic>> updateAttachment(
    String attachmentId,
    Map<String, dynamic> patch,
  ) async {
    final row = await _client
        .from(_attachmentsTable)
        .update(patch)
        .eq('id', attachmentId)
        .select()
        .single();
    return row;
  }
}
