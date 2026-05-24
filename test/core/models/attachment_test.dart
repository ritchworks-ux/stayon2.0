import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/attachment.dart';

void main() {
  test('round-trips via JSON with all fields populated', () {
    final attachment = Attachment(
      id: 'att-1',
      ownerId: 'user-1',
      itemId: 'item-1',
      filename: 'receipt.jpg',
      contentType: 'image/jpeg',
      fileSizeBytes: 1024000,
      storagePath: 'gs://bucket/users/user-1/attachments/att-1',
      storageTier: 'local',
      extractionType: 'receipt',
      extractionData: {'vendor': 'Puregold', 'total': 5000},
      extractionConfidence: 0.95,
      extractionReviewedAt: DateTime.utc(2026, 5, 24, 10, 30),
      createdAt: DateTime.utc(2026, 5, 23),
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    expect(Attachment.fromJson(attachment.toJson()), attachment);
  });

  test('round-trips with nullable extraction fields omitted', () {
    final attachment = Attachment(
      id: 'att-2',
      ownerId: 'user-1',
      itemId: 'item-1',
      filename: 'document.pdf',
      contentType: 'application/pdf',
      fileSizeBytes: 2048000,
      storagePath: 'gs://bucket/users/user-1/attachments/att-2',
      storageTier: 'cloud',
      extractionType: null,
      extractionData: null,
      extractionConfidence: null,
      extractionReviewedAt: null,
      createdAt: DateTime.utc(2026, 5, 20),
      updatedAt: DateTime.utc(2026, 5, 20),
    );
    expect(Attachment.fromJson(attachment.toJson()), attachment);
  });

  test('decodes a Supabase row shape with ISO timestamps', () {
    final row = {
      'id': 'att-3',
      'owner_id': 'user-1',
      'item_id': 'item-1',
      'filename': 'barcode.png',
      'content_type': 'image/png',
      'file_size_bytes': 512000,
      'storage_path': 'gs://bucket/users/user-1/attachments/att-3',
      'storage_tier': 'local',
      'extraction_type': 'barcode',
      'extraction_data': {'code': '123456789', 'format': 'EAN-13'},
      'extraction_confidence': 0.98,
      'extraction_reviewed_at': '2026-05-24T10:30:00Z',
      'created_at': '2026-05-23T12:00:00Z',
      'updated_at': '2026-05-24T12:00:00Z',
    };
    final attachment = Attachment.fromJson(row);
    expect(attachment.id, 'att-3');
    expect(attachment.filename, 'barcode.png');
    expect(attachment.extractionType, 'barcode');
    expect(attachment.extractionConfidence, 0.98);
    expect(attachment.createdAt, DateTime.utc(2026, 5, 23, 12));
  });

  test('extracts extraction_data as untyped Map<String,dynamic>', () {
    final attachment = Attachment(
      id: 'att-4',
      ownerId: 'user-1',
      itemId: 'item-1',
      filename: 'test.jpg',
      contentType: 'image/jpeg',
      fileSizeBytes: 1000,
      storagePath: 'path',
      storageTier: 'local',
      extractionType: 'receipt',
      extractionData: {
        'vendor': 'Store A',
        'items': ['item1', 'item2'],
        'total': 1234,
        'confidence_scores': [0.9, 0.85],
      },
      extractionConfidence: 0.88,
      extractionReviewedAt: null,
      createdAt: DateTime.utc(2026, 5, 23),
      updatedAt: DateTime.utc(2026, 5, 23),
    );
    final json = attachment.toJson();
    final restored = Attachment.fromJson(json);
    expect(restored.extractionData, attachment.extractionData);
  });
}
