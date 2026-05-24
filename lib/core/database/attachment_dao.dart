import 'package:drift/drift.dart';
import 'app_database.dart';

part 'attachment_dao.g.dart';

@DriftAccessor(tables: [Attachments])
class AttachmentDao extends DatabaseAccessor<AppDatabase>
    with _$AttachmentDaoMixin {
  AttachmentDao(super.db);

  /// Insert or replace an attachment in the local cache.
  Future<void> insertAttachment(AttachmentsCompanion attachment) async {
    await into(attachments).insertOnConflictUpdate(attachment);
  }

  /// Retrieve all attachments for a given item.
  Future<List<Attachment>> getAttachmentsByItemId(String itemId) async {
    return (select(
      attachments,
    )..where((tbl) => tbl.itemId.equals(itemId))).get();
  }

  /// Retrieve a single attachment by ID.
  Future<Attachment?> getAttachmentById(String attachmentId) async {
    return (select(
      attachments,
    )..where((tbl) => tbl.id.equals(attachmentId))).getSingleOrNull();
  }

  /// Delete an attachment by ID.
  Future<int> deleteAttachment(String attachmentId) async {
    return (delete(
      attachments,
    )..where((tbl) => tbl.id.equals(attachmentId))).go();
  }

  /// Delete all attachments for a given item.
  Future<int> deleteAttachmentsByItemId(String itemId) async {
    return (delete(
      attachments,
    )..where((tbl) => tbl.itemId.equals(itemId))).go();
  }

  /// Retrieve all attachments (unfiltered).
  Future<List<Attachment>> getAllAttachments() async {
    return select(attachments).get();
  }

  /// Clear all attachments from cache.
  Future<int> clearAllAttachments() async {
    return delete(attachments).go();
  }

  /// Count attachments for a given owner.
  Future<int> countByOwnerId(String ownerId) async {
    final query = selectOnly(attachments)
      ..addColumns([countAll()])
      ..where(attachments.ownerId.equals(ownerId));
    final result = await query.map((row) => row.read(countAll())).getSingle();
    return result ?? 0;
  }

  /// Sum total file sizes for a given owner.
  Future<int> sumFileSizesByOwnerId(String ownerId) async {
    final query = selectOnly(attachments)
      ..addColumns([attachments.fileSizeBytes.sum()])
      ..where(attachments.ownerId.equals(ownerId));
    final result = await query
        .map((row) => row.read(attachments.fileSizeBytes.sum()))
        .getSingle();
    return result ?? 0;
  }
}
