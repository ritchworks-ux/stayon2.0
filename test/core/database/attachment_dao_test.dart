import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/database/app_database.dart';

void main() {
  group('AttachmentDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insertAttachment and getAttachmentById', () async {
      final companion = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('receipt.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1024000),
        storagePath: const Value('gs://bucket/users/user-1/attachments/att-1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.attachmentDao.insertAttachment(companion);
      final retrieved = await db.attachmentDao.getAttachmentById('att-1');

      expect(retrieved, isNotNull);
      expect(retrieved!.filename, 'receipt.jpg');
      expect(retrieved.fileSizeBytes, 1024000);
    });

    test('getAttachmentsByItemId returns all attachments for item', () async {
      final att1 = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('file1.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1000),
        storagePath: const Value('path1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      final att2 = AttachmentsCompanion(
        id: const Value('att-2'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('file2.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(2000),
        storagePath: const Value('path2'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      final att3 = AttachmentsCompanion(
        id: const Value('att-3'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-2'),
        filename: const Value('file3.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(3000),
        storagePath: const Value('path3'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      await db.attachmentDao.insertAttachment(att1);
      await db.attachmentDao.insertAttachment(att2);
      await db.attachmentDao.insertAttachment(att3);

      final item1Attachments = await db.attachmentDao.getAttachmentsByItemId(
        'item-1',
      );
      expect(item1Attachments.length, 2);
      expect(
        item1Attachments.map((a) => a.id).toList(),
        containsAll(['att-1', 'att-2']),
      );
    });

    test('deleteAttachment removes single attachment', () async {
      final companion = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('file.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1000),
        storagePath: const Value('path'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      await db.attachmentDao.insertAttachment(companion);
      var retrieved = await db.attachmentDao.getAttachmentById('att-1');
      expect(retrieved, isNotNull);

      await db.attachmentDao.deleteAttachment('att-1');
      retrieved = await db.attachmentDao.getAttachmentById('att-1');
      expect(retrieved, isNull);
    });

    test('getAllAttachments returns all attachments', () async {
      final att1 = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('file1.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1000),
        storagePath: const Value('path1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      final att2 = AttachmentsCompanion(
        id: const Value('att-2'),
        ownerId: const Value('user-2'),
        itemId: const Value('item-2'),
        filename: const Value('file2.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(2000),
        storagePath: const Value('path2'),
        storageTier: const Value('cloud'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      await db.attachmentDao.insertAttachment(att1);
      await db.attachmentDao.insertAttachment(att2);

      final all = await db.attachmentDao.getAllAttachments();
      expect(all.length, 2);
    });

    test('clearAllAttachments removes all attachments', () async {
      final att1 = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('file1.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1000),
        storagePath: const Value('path1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      await db.attachmentDao.insertAttachment(att1);
      var all = await db.attachmentDao.getAllAttachments();
      expect(all.length, 1);

      await db.attachmentDao.clearAllAttachments();
      all = await db.attachmentDao.getAllAttachments();
      expect(all.length, 0);
    });

    test('countByOwnerId returns correct count', () async {
      final att1 = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('file1.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1000),
        storagePath: const Value('path1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      final att2 = AttachmentsCompanion(
        id: const Value('att-2'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-2'),
        filename: const Value('file2.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(2000),
        storagePath: const Value('path2'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      final att3 = AttachmentsCompanion(
        id: const Value('att-3'),
        ownerId: const Value('user-2'),
        itemId: const Value('item-3'),
        filename: const Value('file3.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(3000),
        storagePath: const Value('path3'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      await db.attachmentDao.insertAttachment(att1);
      await db.attachmentDao.insertAttachment(att2);
      await db.attachmentDao.insertAttachment(att3);

      final user1Count = await db.attachmentDao.countByOwnerId('user-1');
      final user2Count = await db.attachmentDao.countByOwnerId('user-2');

      expect(user1Count, 2);
      expect(user2Count, 1);
    });

    test('sumFileSizesByOwnerId returns total bytes', () async {
      final att1 = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('file1.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1000000), // 1 MB
        storagePath: const Value('path1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      final att2 = AttachmentsCompanion(
        id: const Value('att-2'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-2'),
        filename: const Value('file2.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(2000000), // 2 MB
        storagePath: const Value('path2'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      final att3 = AttachmentsCompanion(
        id: const Value('att-3'),
        ownerId: const Value('user-2'),
        itemId: const Value('item-3'),
        filename: const Value('file3.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(5000000), // 5 MB
        storagePath: const Value('path3'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      await db.attachmentDao.insertAttachment(att1);
      await db.attachmentDao.insertAttachment(att2);
      await db.attachmentDao.insertAttachment(att3);

      final user1Total = await db.attachmentDao.sumFileSizesByOwnerId('user-1');
      final user2Total = await db.attachmentDao.sumFileSizesByOwnerId('user-2');

      expect(user1Total, 3000000); // 3 MB
      expect(user2Total, 5000000); // 5 MB
    });

    test('insertOnConflictUpdate replaces existing attachment', () async {
      final companion1 = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('old-name.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(1000),
        storagePath: const Value('path1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 23)),
      );

      await db.attachmentDao.insertAttachment(companion1);
      var retrieved = await db.attachmentDao.getAttachmentById('att-1');
      expect(retrieved!.filename, 'old-name.jpg');

      final companion2 = AttachmentsCompanion(
        id: const Value('att-1'),
        ownerId: const Value('user-1'),
        itemId: const Value('item-1'),
        filename: const Value('new-name.jpg'),
        contentType: const Value('image/jpeg'),
        fileSizeBytes: const Value(2000),
        storagePath: const Value('path1'),
        storageTier: const Value('local'),
        createdAt: Value(DateTime.utc(2026, 5, 23)),
        updatedAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.attachmentDao.insertAttachment(companion2);
      retrieved = await db.attachmentDao.getAttachmentById('att-1');
      expect(retrieved!.filename, 'new-name.jpg');
      expect(retrieved.fileSizeBytes, 2000);
    });
  });
}
