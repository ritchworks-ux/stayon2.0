import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/database/app_database.dart' as db;
import 'package:stayon/core/database/attachment_dao.dart';
import 'package:stayon/core/models/attachment.dart';
import 'package:stayon/features/attachments/data/attachment_data_source.dart';
import 'package:stayon/features/attachments/data/attachment_repository.dart';
import 'package:stayon/features/attachments/data/supabase_attachment_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _MockDataSource extends Mock implements AttachmentDataSource {}

class _MockSupabaseClient extends Mock implements sb.SupabaseClient {}

class _MockGoTrueClient extends Mock implements sb.GoTrueClient {}

class _MockAttachmentDao extends Mock implements AttachmentDao {}

class _MockSupabaseQueryBuilder extends Mock {}

class _FakeUser extends Fake implements sb.User {
  _FakeUser(this.id);
  @override
  final String id;
}

DateTime _now() => DateTime.utc(2026, 5, 24, 10, 0, 0);

const _ownerId = 'user-uuid-1';
const _itemId = 'item-uuid-1';

Map<String, dynamic> _attachmentRow({
  String id = 'att-1',
  String ownerId = _ownerId,
  String itemId = _itemId,
  String filename = 'receipt.jpg',
  String contentType = 'image/jpeg',
  int fileSizeBytes = 1024000,
  String storagePath = 'local://receipt.jpg',
  String storageTier = 'local',
  String? extractionType,
  Map<String, dynamic>? extractionData,
  double? extractionConfidence,
  String? extractionReviewedAt,
  String createdAt = '2026-05-24T10:00:00Z',
  String updatedAt = '2026-05-24T10:00:00Z',
}) => {
  'id': id,
  'owner_id': ownerId,
  'item_id': itemId,
  'filename': filename,
  'content_type': contentType,
  'file_size_bytes': fileSizeBytes,
  'storage_path': storagePath,
  'storage_tier': storageTier,
  'extraction_type': extractionType,
  'extraction_data': extractionData,
  'extraction_confidence': extractionConfidence,
  'extraction_reviewed_at': extractionReviewedAt,
  'created_at': createdAt,
  'updated_at': updatedAt,
};

Attachment _attachment({
  String id = 'att-1',
  String ownerId = _ownerId,
  String itemId = _itemId,
  String filename = 'receipt.jpg',
  String contentType = 'image/jpeg',
  int fileSizeBytes = 1024000,
  String storagePath = 'local://receipt.jpg',
  String storageTier = 'local',
  String? extractionType,
  Map<String, dynamic>? extractionData,
  double? extractionConfidence,
  DateTime? extractionReviewedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) => Attachment(
  id: id,
  ownerId: ownerId,
  itemId: itemId,
  filename: filename,
  contentType: contentType,
  fileSizeBytes: fileSizeBytes,
  storagePath: storagePath,
  storageTier: storageTier,
  extractionType: extractionType,
  extractionData: extractionData,
  extractionConfidence: extractionConfidence,
  extractionReviewedAt: extractionReviewedAt,
  createdAt: createdAt ?? DateTime.utc(2026, 5, 24, 10),
  updatedAt: updatedAt ?? DateTime.utc(2026, 5, 24, 10),
);

void main() {
  late _MockDataSource ds;
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late _MockAttachmentDao attachmentDao;
  late SupabaseAttachmentRepository repo;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(const db.AttachmentsCompanion());
  });

  setUp(() {
    ds = _MockDataSource();
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    attachmentDao = _MockAttachmentDao();

    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(_FakeUser(_ownerId));

    repo = SupabaseAttachmentRepository(
      client: client,
      dataSource: ds,
      attachmentDao: attachmentDao,
      now: _now,
    );
  });

  group('add', () {
    test('returns attachment with owner_id and local storage path', () async {
      final att = _attachment(id: 'new-att-1', storagePath: 'local://test.jpg');
      when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
        (_) async => {
          'owner_id': _ownerId,
          'tier': 'free',
          'total_bytes_used': 0,
          'quota_limit_bytes': 52428800,
          'attachment_count': 0,
          'attachment_limit': 10,
        },
      );
      when(
        () => attachmentDao.insertAttachment(any()),
      ).thenAnswer((_) async {});

      final result = await repo.add(att, Uint8List.fromList([1, 2, 3]));

      expect(result.id, 'new-att-1');
      expect(result.ownerId, _ownerId);
      expect(result.storagePath, 'local://test.jpg');
      expect(result.storageTier, 'local');

      // Verify DataSource was NOT called (free tier local-only)
      verifyNever(() => ds.insertAttachment(any()));
      // Verify Drift was called
      verify(() => attachmentDao.insertAttachment(any())).called(1);
    });

    test('syncs to Drift cache after Supabase insert succeeds', () async {
      final att = _attachment(id: 'new-att-1');
      when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
        (_) async => {
          'owner_id': _ownerId,
          'tier': 'free',
          'total_bytes_used': 0,
          'quota_limit_bytes': 52428800,
          'attachment_count': 0,
          'attachment_limit': 10,
        },
      );
      when(
        () => ds.insertAttachment(any()),
      ).thenAnswer((_) async => _attachmentRow(id: 'new-att-1'));
      when(
        () => attachmentDao.insertAttachment(any()),
      ).thenAnswer((_) async {});

      await repo.add(att, Uint8List.fromList([1, 2, 3]));

      verify(() => attachmentDao.insertAttachment(any())).called(1);
    });

    test('throws QuotaException if free tier exceeds 10 attachments', () async {
      when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
        (_) async => {
          'owner_id': _ownerId,
          'tier': 'free',
          'total_bytes_used': 10000000,
          'quota_limit_bytes': 52428800,
          'attachment_count': 10,
          'attachment_limit': 10,
        },
      );

      expect(
        () => repo.add(_attachment(), Uint8List.fromList([1])),
        throwsA(
          isA<QuotaException>().having(
            (e) => e.code,
            'code',
            'attachment_limit_exceeded',
          ),
        ),
      );
    });

    test(
      'throws QuotaException if free tier exceeds 50 MB total bytes',
      () async {
        when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
          (_) async => {
            'owner_id': _ownerId,
            'tier': 'free',
            'total_bytes_used': 51000000,
            'quota_limit_bytes': 52428800,
            'attachment_count': 5,
            'attachment_limit': 10,
          },
        );

        expect(
          () => repo.add(
            _attachment(fileSizeBytes: 2000000),
            Uint8List.fromList(List.filled(2000000, 0)),
          ),
          throwsA(
            isA<QuotaException>().having(
              (e) => e.code,
              'code',
              'storage_limit_exceeded',
            ),
          ),
        );
      },
    );

    test('allows premium tier to bypass quota checks', () async {
      when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
        (_) async => {
          'owner_id': _ownerId,
          'tier': 'premium',
          'total_bytes_used': 10000000,
          'quota_limit_bytes': 5368709120, // 5GB for premium
          'attachment_count': 100,
          'attachment_limit': 1000,
        },
      );
      when(
        () => ds.insertAttachment(any()),
      ).thenAnswer((_) async => _attachmentRow(id: 'new-att-1'));
      when(
        () => attachmentDao.insertAttachment(any()),
      ).thenAnswer((_) async {});

      final result = await repo.add(_attachment(), Uint8List.fromList([1, 2]));

      expect(result.ownerId, _ownerId);
    });

    test('free tier insert skips Supabase, saves to Drift only', () async {
      when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
        (_) async => {
          'owner_id': _ownerId,
          'tier': 'free',
          'total_bytes_used': 0,
          'quota_limit_bytes': 52428800,
          'attachment_count': 0,
          'attachment_limit': 10,
        },
      );
      when(
        () => attachmentDao.insertAttachment(any()),
      ).thenAnswer((_) async {});

      final att = _attachment(id: 'new-att-1', storagePath: 'local://test.jpg');
      await repo.add(att, Uint8List.fromList([1, 2, 3]));

      // Verify Supabase insert was NOT called for free tier
      verifyNever(() => ds.insertAttachment(any()));
      // Verify Drift insert WAS called
      verify(() => attachmentDao.insertAttachment(any())).called(1);
    });

    test('premium tier insert saves to both Supabase and Drift', () async {
      when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
        (_) async => {
          'owner_id': _ownerId,
          'tier': 'premium',
          'total_bytes_used': 0,
          'quota_limit_bytes': 5368709120,
          'attachment_count': 0,
          'attachment_limit': 1000,
        },
      );
      when(
        () => ds.insertAttachment(any()),
      ).thenAnswer((_) async => _attachmentRow(id: 'new-att-1'));
      when(
        () => attachmentDao.insertAttachment(any()),
      ).thenAnswer((_) async {});

      final att = _attachment(id: 'new-att-1');
      await repo.add(att, Uint8List.fromList([1, 2, 3]));

      // Verify both Supabase and Drift inserts were called
      verify(() => ds.insertAttachment(any())).called(1);
      verify(() => attachmentDao.insertAttachment(any())).called(1);
    });

    test('throws not_signed_in if no current user', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(
        () => repo.add(_attachment(), Uint8List.fromList([1])),
        throwsA(
          isA<AttachmentException>().having(
            (e) => e.code,
            'code',
            'not_signed_in',
          ),
        ),
      );
    });

    test('maps PostgrestException with code 42501 to RLS exception', () async {
      when(() => ds.getQuotaForOwner(_ownerId)).thenAnswer(
        (_) async => {
          'owner_id': _ownerId,
          'tier': 'premium',
          'total_bytes_used': 10000000,
          'quota_limit_bytes': 5368709120,
          'attachment_count': 5,
          'attachment_limit': 1000,
        },
      );
      when(() => ds.insertAttachment(any())).thenThrow(
        const sb.PostgrestException(message: 'denied', code: '42501'),
      );

      expect(
        () => repo.add(_attachment(), Uint8List.fromList([1])),
        throwsA(
          isA<AttachmentException>().having((e) => e.code, 'code', 'rls'),
        ),
      );
    });
  });

  group('getByItemId', () {
    test('returns attachments for the given item', () async {
      when(() => ds.selectByItemId(_itemId)).thenAnswer(
        (_) async => [_attachmentRow(id: 'att-1'), _attachmentRow(id: 'att-2')],
      );

      final attachments = await repo.getByItemId(_itemId);

      expect(attachments, hasLength(2));
      expect(attachments.first.id, 'att-1');
      expect(attachments[1].id, 'att-2');
      verify(() => ds.selectByItemId(_itemId)).called(1);
    });

    test('returns empty list if no attachments found', () async {
      when(() => ds.selectByItemId(_itemId)).thenAnswer((_) async => []);

      final attachments = await repo.getByItemId(_itemId);

      expect(attachments, isEmpty);
    });

    test('maps RLS violation to AttachmentException', () async {
      when(() => ds.selectByItemId(any())).thenThrow(
        const sb.PostgrestException(message: 'denied', code: '42501'),
      );

      expect(
        () => repo.getByItemId(_itemId),
        throwsA(
          isA<AttachmentException>().having((e) => e.code, 'code', 'rls'),
        ),
      );
    });
  });

  group('getByOwnerId', () {
    test('returns all attachments owned by user', () async {
      when(() => ds.selectByOwnerId(_ownerId)).thenAnswer(
        (_) async => [
          _attachmentRow(id: 'att-1', itemId: _itemId),
          _attachmentRow(id: 'att-2', itemId: 'other-item'),
        ],
      );

      final attachments = await repo.getByOwnerId(_ownerId);

      expect(attachments, hasLength(2));
      expect(attachments.first.id, 'att-1');
      expect(attachments[1].id, 'att-2');
    });

    test('throws not_signed_in if no current user', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(
        () => repo.getByOwnerId(_ownerId),
        throwsA(
          isA<AttachmentException>().having(
            (e) => e.code,
            'code',
            'not_signed_in',
          ),
        ),
      );
    });
  });

  group('delete', () {
    test('deletes from both Supabase and Drift cache', () async {
      when(() => ds.deleteAttachment('att-1')).thenAnswer((_) async {});
      when(
        () => attachmentDao.deleteAttachment('att-1'),
      ).thenAnswer((_) async => 1);

      await repo.delete('att-1');

      verify(() => ds.deleteAttachment('att-1')).called(1);
      verify(() => attachmentDao.deleteAttachment('att-1')).called(1);
    });

    test('throws not_signed_in if no current user', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(
        () => repo.delete('att-1'),
        throwsA(
          isA<AttachmentException>().having(
            (e) => e.code,
            'code',
            'not_signed_in',
          ),
        ),
      );
    });

    test('maps RLS violation to AttachmentException', () async {
      when(() => ds.deleteAttachment(any())).thenThrow(
        const sb.PostgrestException(message: 'denied', code: '42501'),
      );

      expect(
        () => repo.delete('att-1'),
        throwsA(
          isA<AttachmentException>().having((e) => e.code, 'code', 'rls'),
        ),
      );
    });
  });

  group('update', () {
    test('updates metadata without writing new file', () async {
      final patch = {
        'extraction_type': 'receipt',
        'extraction_data': {'amount': 5000, 'date': '2026-05-24'},
      };
      when(() => ds.updateAttachment(any(), any())).thenAnswer(
        (_) async => _attachmentRow(
          id: 'att-1',
          extractionType: 'receipt',
          extractionData: {'amount': 5000, 'date': '2026-05-24'},
        ),
      );

      final result = await repo.update('att-1', patch);

      expect(result.extractionType, 'receipt');
      expect(result.extractionData, {'amount': 5000, 'date': '2026-05-24'});
    });

    test('throws not_signed_in if no current user', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(
        () => repo.update('att-1', {'extraction_type': 'receipt'}),
        throwsA(
          isA<AttachmentException>().having(
            (e) => e.code,
            'code',
            'not_signed_in',
          ),
        ),
      );
    });

    test('maps RLS violation to AttachmentException', () async {
      when(() => ds.updateAttachment(any(), any())).thenThrow(
        const sb.PostgrestException(message: 'denied', code: '42501'),
      );

      expect(
        () => repo.update('att-1', {'extraction_type': 'receipt'}),
        throwsA(
          isA<AttachmentException>().having((e) => e.code, 'code', 'rls'),
        ),
      );
    });
  });
}
