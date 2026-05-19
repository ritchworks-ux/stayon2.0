import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/data/item_repository.dart';
import 'package:stayon/features/items/data/items_data_source.dart';
import 'package:stayon/features/items/data/supabase_item_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class _MockDataSource extends Mock implements ItemsDataSource {}

class _MockSupabaseClient extends Mock implements sb.SupabaseClient {}

class _MockGoTrueClient extends Mock implements sb.GoTrueClient {}

class _FakeUser extends Fake implements sb.User {
  _FakeUser(this.id);
  @override
  final String id;
}

DateTime _now() => DateTime.utc(2026, 5, 18, 9, 0, 0);

const _ownerId = 'owner-uuid-1';

Map<String, dynamic> _row({
  String id = 'row-1',
  String ownerId = _ownerId,
  String name = 'PhilHealth',
  String category = 'id_license',
  String dateType = 'renews',
  String targetDate = '2026-12-31',
  String? notes,
  String? assigneeLabel,
  int? amountMinor,
  String status = 'active',
  String? trashedAt,
}) => {
  'id': id,
  'owner_id': ownerId,
  'name': name,
  'category': category,
  'date_type': dateType,
  'target_date': targetDate,
  'notes': notes,
  'assignee_label': assigneeLabel,
  'amount_minor': amountMinor,
  'currency_code': 'PHP',
  'status': status,
  'trashed_at': trashedAt,
  'created_at': '2026-01-01T00:00:00Z',
  'updated_at': '2026-01-01T00:00:00Z',
};

void main() {
  late _MockDataSource ds;
  late _MockSupabaseClient client;
  late _MockGoTrueClient auth;
  late SupabaseItemRepository repo;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    ds = _MockDataSource();
    client = _MockSupabaseClient();
    auth = _MockGoTrueClient();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentUser).thenReturn(_FakeUser(_ownerId));
    repo = SupabaseItemRepository(client: client, dataSource: ds, now: _now);
  });

  group('fetchActive', () {
    test('returns parsed items from data source', () async {
      when(() => ds.selectActive(_ownerId)).thenAnswer((_) async => [_row()]);

      final items = await repo.fetchActive();

      expect(items, hasLength(1));
      expect(items.first.id, 'row-1');
      expect(items.first.category, ItemCategory.idLicense);
      expect(items.first.status, ItemStatus.active);
      verify(() => ds.selectActive(_ownerId)).called(1);
    });

    test('throws not_signed_in if no current user', () async {
      when(() => auth.currentUser).thenReturn(null);

      expect(
        () => repo.fetchActive(),
        throwsA(
          isA<ItemException>().having((e) => e.code, 'code', 'not_signed_in'),
        ),
      );
    });

    test('maps RLS denial (42501) to ItemException(rls)', () async {
      when(() => ds.selectActive(_ownerId)).thenThrow(
        const sb.PostgrestException(message: 'denied', code: '42501'),
      );

      expect(
        () => repo.fetchActive(),
        throwsA(isA<ItemException>().having((e) => e.code, 'code', 'rls')),
      );
    });
  });

  group('getById', () {
    test('returns the parsed item', () async {
      when(() => ds.selectById('row-1')).thenAnswer((_) async => _row());

      final item = await repo.getById('row-1');

      expect(item.id, 'row-1');
    });

    test('throws not_found when row is null', () async {
      when(() => ds.selectById(any())).thenAnswer((_) async => null);

      expect(
        () => repo.getById('missing'),
        throwsA(
          isA<ItemException>().having((e) => e.code, 'code', 'not_found'),
        ),
      );
    });
  });

  group('add', () {
    test('payload includes owner_id from auth.uid()', () async {
      when(() => ds.insert(any())).thenAnswer((inv) async {
        final p = inv.positionalArguments.first as Map<String, dynamic>;
        return _row(id: 'new', ownerId: p['owner_id'] as String);
      });

      await repo.add(
        name: 'Bread',
        category: ItemCategory.grocery,
        dateType: ItemDateType.expires,
        targetDate: DateTime.utc(2026, 5, 25),
      );

      final captured =
          verify(() => ds.insert(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['owner_id'], _ownerId);
      expect(captured['name'], 'Bread');
      expect(captured['category'], 'grocery');
      expect(captured['date_type'], 'expires');
      expect(captured['target_date'], '2026-05-25');
      // null optionals are NOT in the payload
      expect(captured.containsKey('notes'), isFalse);
      expect(captured.containsKey('amount_minor'), isFalse);
      expect(captured.containsKey('assignee_label'), isFalse);
    });

    test('payload includes optional fields when supplied', () async {
      when(() => ds.insert(any())).thenAnswer((_) async => _row());

      await repo.add(
        name: 'Insurance',
        category: ItemCategory.insurance,
        dateType: ItemDateType.renews,
        targetDate: DateTime.utc(2026, 12, 31),
        notes: 'Annual',
        assigneeLabel: 'Mom',
        amountMinor: 250000,
      );

      final captured =
          verify(() => ds.insert(captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['notes'], 'Annual');
      expect(captured['assignee_label'], 'Mom');
      expect(captured['amount_minor'], 250000);
    });

    test('maps RLS denial to ItemException(rls)', () async {
      when(
        () => ds.insert(any()),
      ).thenThrow(const sb.PostgrestException(message: 'rls', code: '42501'));

      expect(
        () => repo.add(
          name: 'x',
          category: ItemCategory.other,
          dateType: ItemDateType.due,
          targetDate: DateTime.utc(2026, 6, 1),
        ),
        throwsA(isA<ItemException>().having((e) => e.code, 'code', 'rls')),
      );
    });
  });

  group('update', () {
    test('only includes non-null fields in the patch', () async {
      when(() => ds.updateById(any(), any())).thenAnswer((_) async => _row());

      await repo.update('row-1', name: 'New name', amountMinor: 9999);

      final captured =
          verify(() => ds.updateById('row-1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['name'], 'New name');
      expect(captured['amount_minor'], 9999);
      expect(captured.containsKey('category'), isFalse);
      expect(captured.containsKey('date_type'), isFalse);
      expect(captured.containsKey('target_date'), isFalse);
      expect(captured.containsKey('notes'), isFalse);
    });

    test('serializes target_date as YYYY-MM-DD', () async {
      when(() => ds.updateById(any(), any())).thenAnswer((_) async => _row());

      await repo.update('row-1', targetDate: DateTime.utc(2027, 1, 5));

      final captured =
          verify(() => ds.updateById('row-1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['target_date'], '2027-01-05');
    });
  });

  group('archive', () {
    test('sets status=archived', () async {
      when(
        () => ds.updateById(any(), any()),
      ).thenAnswer((_) async => _row(status: 'archived'));

      final item = await repo.archive('row-1');

      final captured =
          verify(() => ds.updateById('row-1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured, {'status': 'archived'});
      expect(item.status, ItemStatus.archived);
    });
  });

  group('trash', () {
    test('sets status=trashed and trashed_at to fixed _now', () async {
      when(() => ds.updateById(any(), any())).thenAnswer(
        (_) async =>
            _row(status: 'trashed', trashedAt: '2026-05-18T09:00:00.000Z'),
      );

      final item = await repo.trash('row-1');

      final captured =
          verify(() => ds.updateById('row-1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured['status'], 'trashed');
      expect(captured['trashed_at'], '2026-05-18T09:00:00.000Z');
      expect(item.status, ItemStatus.trashed);
    });
  });

  group('restore', () {
    test('sets status=active and clears trashed_at', () async {
      when(
        () => ds.updateById(any(), any()),
      ).thenAnswer((_) async => _row(status: 'active'));

      final item = await repo.restore('row-1');

      final captured =
          verify(() => ds.updateById('row-1', captureAny())).captured.single
              as Map<String, dynamic>;
      expect(captured, {'status': 'active', 'trashed_at': null});
      expect(item.status, ItemStatus.active);
    });
  });
}
