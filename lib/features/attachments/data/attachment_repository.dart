import 'dart:typed_data';

import '../../../core/models/attachment.dart';
import '../../../core/models/storage_quota.dart';

/// Repository contract for attachment persistence.
///
/// Manages attachment lifecycle: creation, retrieval, deletion, and metadata
/// updates. All ownership and quota enforcement is transparent to the caller.
///
/// V0.5 (Phase 3 MVP) stores attachments locally (Drift cache) and metadata
/// in Supabase, with RLS enforcement for privacy.
abstract interface class AttachmentRepository {
  /// Creates a new attachment owned by the current user.
  ///
  /// Enforces free tier quotas:
  /// - Max 10 attachments per user
  /// - Max 50 MB total storage per user
  ///
  /// Premium users have higher limits.
  ///
  /// Throws [AttachmentException] on failure:
  /// - `not_signed_in`: no authenticated user
  /// - `attachment_limit_exceeded`: free tier exceeded 10 items
  /// - `storage_limit_exceeded`: free tier exceeded 50 MB
  /// - `rls`: RLS policy denied the insert
  /// - `invalid_file`: file size or type unsupported
  Future<Attachment> add(Attachment attachment, Uint8List bytes);

  /// Returns all attachments for the given item.
  ///
  /// RLS enforces: caller can only see attachments for their own items.
  ///
  /// Throws [AttachmentException] on failure.
  Future<List<Attachment>> getByItemId(String itemId);

  /// Returns all attachments owned by the given user.
  ///
  /// RLS enforces: caller can only retrieve their own attachments.
  ///
  /// Throws [AttachmentException] on failure or if not signed in.
  Future<List<Attachment>> getByOwnerId(String ownerId);

  /// Deletes an attachment from both Supabase and local cache.
  ///
  /// RLS enforces: caller can only delete their own attachments.
  ///
  /// Throws [AttachmentException] on failure or if not signed in.
  Future<void> delete(String attachmentId);

  /// Updates attachment metadata (extraction data, confidence, etc.).
  ///
  /// Does NOT modify the file itself. The [patch] map contains only
  /// the fields to update (e.g., {'extraction_type': 'receipt'}).
  ///
  /// RLS enforces: caller can only update their own attachments.
  ///
  /// Throws [AttachmentException] on failure.
  Future<Attachment> update(String attachmentId, Map<String, dynamic> patch);

  /// Retrieves the storage quota for the current authenticated user.
  ///
  /// Returns a [StorageQuota] object with usage metrics and tier information.
  /// Useful for quota display in settings or upload flows.
  ///
  /// Throws [AttachmentException] on failure or if not signed in.
  Future<StorageQuota> getStorageQuota();
}

/// Thrown by [AttachmentRepository] for any user-actionable failure.
/// UI maps [code] to a friendly message.
class AttachmentException implements Exception {
  AttachmentException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AttachmentException($code): $message';
}

/// Thrown by [AttachmentRepository] when quota limits are exceeded.
class QuotaException implements Exception {
  QuotaException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'QuotaException($code): $message';
}
