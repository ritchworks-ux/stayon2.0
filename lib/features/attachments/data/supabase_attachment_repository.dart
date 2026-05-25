import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/database/app_database.dart' show AttachmentsCompanion;
import '../../../core/database/attachment_dao.dart';
import '../../../core/models/attachment.dart';
import '../../../core/services/supabase_service.dart';
import 'attachment_data_source.dart';
import 'attachment_repository.dart';

/// Supabase-backed [AttachmentRepository]. All ownership is enforced by RLS
/// on the server; this class is responsible for enforcing quota limits,
/// setting `owner_id` and `storage_path` at insert time, and mapping
/// Postgres errors to friendly exceptions.
///
/// Quota enforcement:
/// - Free tier: max 10 attachments, 50 MB total
/// - Premium tier: relaxed limits
///
/// Storage model (v0.5):
/// - Files stored locally (Drift cache) with `storagePath='local'`
/// - Metadata persisted in Supabase for sync across devices
class SupabaseAttachmentRepository implements AttachmentRepository {
  SupabaseAttachmentRepository({
    sb.SupabaseClient? client,
    AttachmentDataSource? dataSource,
    AttachmentDao? attachmentDao,
    DateTime Function()? now,
  }) : _client = client ?? SupabaseService.client,
       _ds =
           dataSource ??
           SupabaseAttachmentDataSource(client ?? SupabaseService.client),
       _attachmentDao = attachmentDao,
       _now = now ?? DateTime.now;

  final sb.SupabaseClient _client;
  final AttachmentDataSource _ds;
  final AttachmentDao? _attachmentDao;
  final DateTime Function() _now;

  /// The current authenticated user's id. Throws [AttachmentException] if
  /// no user is signed in.
  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw AttachmentException('not_signed_in', 'You must be signed in');
    }
    return id;
  }

  @override
  Future<Attachment> add(Attachment attachment, Uint8List bytes) async {
    final uid = _uid;

    // Fetch quota for the current user (before checking limits)
    final quota = await _quotaForUser(uid);

    // Enforce free tier quota limits
    if (quota['tier'] as String == 'free') {
      if ((quota['attachment_count'] as int) >=
          (quota['attachment_limit'] as int)) {
        throw QuotaException(
          'attachment_limit_exceeded',
          'Free tier limited to ${quota['attachment_limit']} attachments per item',
        );
      }

      final newTotalBytes =
          (quota['total_bytes_used'] as int) + bytes.lengthInBytes;
      if (newTotalBytes > (quota['quota_limit_bytes'] as int)) {
        throw QuotaException(
          'storage_limit_exceeded',
          'Free tier limited to ${_formatBytes(quota['quota_limit_bytes'] as int)} total storage',
        );
      }
    }

    // Build payload for Supabase insert
    // If attachment.id is empty, let Supabase generate via gen_random_uuid()
    final now = _now().toUtc().toIso8601String();
    final attachmentId = attachment.id.isEmpty ? null : attachment.id;

    final payload = <String, dynamic>{
      if (attachmentId case final String id) 'id': id,
      'owner_id': uid,
      'item_id': attachment.itemId,
      'filename': attachment.filename,
      'content_type': attachment.contentType,
      'file_size_bytes': bytes.lengthInBytes,
      'storage_path': attachment.storagePath.isEmpty
          ? 'local://${attachmentId ?? 'auto-generated'}'
          : attachment.storagePath,
      'storage_tier': 'local',
      if (attachment.extractionType != null)
        'extraction_type': attachment.extractionType,
      if (attachment.extractionData != null)
        'extraction_data': attachment.extractionData,
      if (attachment.extractionConfidence != null)
        'extraction_confidence': attachment.extractionConfidence,
      'created_at': now,
      'updated_at': now,
    };

    try {
      final row = await _ds.insertAttachment(payload);
      final result = Attachment.fromJson(row);

      // Sync to Drift cache for offline resilience
      if (_attachmentDao != null) {
        await _syncToDrift(result);
      }

      return result;
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'add_failed');
    }
  }

  @override
  Future<List<Attachment>> getByItemId(String itemId) async {
    try {
      final rows = await _ds.selectByItemId(itemId);
      return rows.map(Attachment.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'fetch_failed');
    }
  }

  @override
  Future<List<Attachment>> getByOwnerId(String ownerId) async {
    // Verify signed in (RLS enforcement at DB level)
    _uid;
    try {
      final rows = await _ds.selectByOwnerId(ownerId);
      return rows.map(Attachment.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'fetch_failed');
    }
  }

  @override
  Future<void> delete(String attachmentId) async {
    // Verify signed in (RLS enforcement at DB level)
    _uid;

    try {
      // Delete from Supabase first
      await _ds.deleteAttachment(attachmentId);

      // Delete from Drift cache
      if (_attachmentDao != null) {
        await _attachmentDao.deleteAttachment(attachmentId);
      }
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'delete_failed');
    }
  }

  @override
  Future<Attachment> update(
    String attachmentId,
    Map<String, dynamic> patch,
  ) async {
    // Verify signed in (RLS enforcement at DB level)
    _uid;

    try {
      final now = _now().toUtc().toIso8601String();
      final patchWithTimestamp = {...patch, 'updated_at': now};

      final row = await _ds.updateAttachment(attachmentId, patchWithTimestamp);
      return Attachment.fromJson(row);
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'update_failed');
    }
  }

  /// Fetch quota record for user, or create default free-tier quota if missing.
  Future<Map<String, dynamic>> _quotaForUser(String uid) async {
    try {
      final quota = await _ds.getQuotaForOwner(uid);

      // Shouldn't happen with proper migrations, but handle gracefully
      if (quota == null) {
        return {
          'owner_id': uid,
          'tier': 'free',
          'total_bytes_used': 0,
          'quota_limit_bytes': 52428800, // 50 MB
          'attachment_count': 0,
          'attachment_limit': 10,
        };
      }

      return quota;
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'quota_fetch_failed');
    }
  }

  /// Sync attachment to local Drift cache for offline access.
  Future<void> _syncToDrift(Attachment attachment) async {
    if (_attachmentDao == null) return;

    try {
      await _attachmentDao.insertAttachment(
        AttachmentsCompanion(
          id: Value(attachment.id),
          ownerId: Value(attachment.ownerId),
          itemId: Value(attachment.itemId),
          filename: Value(attachment.filename),
          contentType: Value(attachment.contentType),
          fileSizeBytes: Value(attachment.fileSizeBytes),
          storagePath: Value(attachment.storagePath),
          storageTier: Value(attachment.storageTier),
          extractionType: attachment.extractionType == null
              ? const Value.absent()
              : Value(attachment.extractionType),
          extractionData: attachment.extractionData == null
              ? const Value.absent()
              : Value(_jsonToString(attachment.extractionData)),
          extractionConfidence: attachment.extractionConfidence == null
              ? const Value.absent()
              : Value(attachment.extractionConfidence),
          extractionReviewedAt: attachment.extractionReviewedAt == null
              ? const Value.absent()
              : Value(attachment.extractionReviewedAt),
          createdAt: Value(attachment.createdAt),
          updatedAt: Value(attachment.updatedAt),
        ),
      );
    } catch (e) {
      // Log but don't fail the operation if Drift sync fails
      // (user's metadata is already in Supabase)
      // ignore: avoid_print
      print('Failed to sync attachment to Drift cache: $e');
    }
  }

  /// Convert Map to JSON string for Drift storage.
  String _jsonToString(Map<String, dynamic>? data) {
    if (data == null) return '';
    return jsonEncode(data);
  }

  /// Translates raw Postgres / PostgREST errors into [AttachmentException].
  /// 42501 is the RLS-violation code.
  AttachmentException _map(sb.PostgrestException e, String fallback) {
    if (e.code == '42501') {
      return AttachmentException(
        'rls',
        'You do not have access to this attachment',
      );
    }
    return AttachmentException(e.code ?? fallback, e.message);
  }

  /// Format bytes to human-readable string (e.g., "50 MB").
  String _formatBytes(int bytes) {
    const mb = 1024 * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(0)} MB';
    }
    const kb = 1024;
    if (bytes >= kb) {
      return '${(bytes / kb).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }
}
