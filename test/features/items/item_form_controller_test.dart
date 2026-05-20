import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/controllers/item_form_controller.dart';
import 'package:stayon/features/items/controllers/item_providers.dart';
import 'package:stayon/features/items/data/item_repository.dart';

class _MockRepo extends Mock implements ItemRepository {}

class _FakeItem extends Fake implements Item {}

Item _stub({String id = 'i'}) => Item(
  id: id,
  ownerId: 'o',
  name: 'X',
  category: ItemCategory.other,
  dateType: ItemDateType.expires,
  targetDate: DateTime.utc(2026, 6, 1),
  currencyCode: 'PHP',
  status: ItemStatus.active,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late _MockRepo repo;

  setUpAll(() {
    registerFallbackValue(_FakeItem());
    registerFallbackValue(ItemCategory.other);
    registerFallbackValue(ItemDateType.due);
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  setUp(() {
    repo = _MockRepo();
  });

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [itemRepositoryProvider.overrideWithValue(repo)],
  );

  group('submitNew', () {
    test('delegates to repository.add and invalidates itemsProvider', () async {
      // First fetch returns one item; after invalidate, returns two.
      var fetchCount = 0;
      when(() => repo.fetchActive()).thenAnswer((_) async {
        fetchCount++;
        return fetchCount == 1
            ? [_stub(id: 'a')]
            : [_stub(id: 'a'), _stub(id: 'b')];
      });
      when(
        () => repo.add(
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenAnswer((_) async => _stub(id: 'b'));

      final c = makeContainer();
      addTearDown(c.dispose);

      // First read — caches result with 1 item.
      var items = await c.read(itemsProvider.future);
      expect(items, hasLength(1));
      expect(fetchCount, 1);

      // Submit a new item — should trigger invalidation.
      await c
          .read(itemFormControllerProvider.notifier)
          .submitNew(
            name: 'New',
            category: ItemCategory.bill,
            dateType: ItemDateType.due,
            targetDate: DateTime.utc(2026, 6, 1),
          );

      // Reading itemsProvider again must re-fetch (count goes to 2)
      // and reflect the new list.
      items = await c.read(itemsProvider.future);
      expect(items, hasLength(2));
      expect(fetchCount, 2);

      verify(
        () => repo.add(
          name: 'New',
          category: ItemCategory.bill,
          dateType: ItemDateType.due,
          targetDate: DateTime.utc(2026, 6, 1),
          notes: null,
          assigneeLabel: null,
          amountMinor: null,
        ),
      ).called(1);
      expect(c.read(itemFormControllerProvider).hasError, isFalse);
    });

    test('surfaces ItemException as error state', () async {
      when(
        () => repo.add(
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenThrow(ItemException('rls', 'denied'));

      final c = makeContainer();
      addTearDown(c.dispose);

      await c
          .read(itemFormControllerProvider.notifier)
          .submitNew(
            name: 'x',
            category: ItemCategory.other,
            dateType: ItemDateType.due,
            targetDate: DateTime.utc(2026, 6, 1),
          );

      final s = c.read(itemFormControllerProvider);
      expect(s.hasError, isTrue);
      expect(s.error, isA<ItemException>());
      expect((s.error! as ItemException).code, 'rls');
    });

    test('not_signed_in error from repository surfaces cleanly', () async {
      when(
        () => repo.add(
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenThrow(ItemException('not_signed_in', 'You must be signed in'));

      final c = makeContainer();
      addTearDown(c.dispose);

      await c
          .read(itemFormControllerProvider.notifier)
          .submitNew(
            name: 'x',
            category: ItemCategory.other,
            dateType: ItemDateType.due,
            targetDate: DateTime.utc(2026, 6, 1),
          );

      final s = c.read(itemFormControllerProvider);
      expect((s.error! as ItemException).code, 'not_signed_in');
    });

    test('error path does NOT invalidate itemsProvider', () async {
      var fetchCount = 0;
      when(() => repo.fetchActive()).thenAnswer((_) async {
        fetchCount++;
        return [_stub(id: 'a')];
      });
      when(
        () => repo.add(
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenThrow(ItemException('add_failed', 'boom'));

      final c = makeContainer();
      addTearDown(c.dispose);

      await c.read(itemsProvider.future);
      expect(fetchCount, 1);

      await c
          .read(itemFormControllerProvider.notifier)
          .submitNew(
            name: 'x',
            category: ItemCategory.other,
            dateType: ItemDateType.due,
            targetDate: DateTime.utc(2026, 6, 1),
          );

      // Read again — must use cached value (no re-fetch).
      await c.read(itemsProvider.future);
      expect(fetchCount, 1);
    });
  });

  group('submitEdit', () {
    test('delegates to repository.update and invalidates itemsProvider '
        'AND itemByIdProvider (edit-refresh regression)', () async {
      var fetchCount = 0;
      var getByIdCount = 0;
      when(() => repo.fetchActive()).thenAnswer((_) async {
        fetchCount++;
        return [_stub(id: 'a')];
      });
      when(() => repo.getById('a')).thenAnswer((_) async {
        getByIdCount++;
        return _stub(id: 'a');
      });
      when(
        () => repo.update(
          any(),
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenAnswer((_) async => _stub(id: 'a'));

      final c = makeContainer();
      addTearDown(c.dispose);

      // Prime both providers so we can detect invalidation re-fetches.
      await c.read(itemsProvider.future);
      await c.read(itemByIdProvider('a').future);
      expect(fetchCount, 1);
      expect(getByIdCount, 1);

      await c
          .read(itemFormControllerProvider.notifier)
          .submitEdit('a', name: 'New name');

      // Both providers re-fetch after invalidation.
      await c.read(itemsProvider.future);
      await c.read(itemByIdProvider('a').future);
      expect(fetchCount, 2);
      expect(getByIdCount, 2);

      verify(
        () => repo.update(
          'a',
          name: 'New name',
          category: null,
          dateType: null,
          targetDate: null,
          notes: null,
          assigneeLabel: null,
          amountMinor: null,
        ),
      ).called(1);
    });

    test('submitEdit sends the changed target_date in the update', () async {
      when(() => repo.fetchActive()).thenAnswer((_) async => []);
      when(() => repo.getById(any())).thenAnswer((_) async => _stub(id: 'a'));
      when(
        () => repo.update(
          any(),
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenAnswer((_) async => _stub(id: 'a'));

      final c = makeContainer();
      addTearDown(c.dispose);

      final newDate = DateTime.utc(2027, 3, 15);
      await c
          .read(itemFormControllerProvider.notifier)
          .submitEdit('a', targetDate: newDate);

      final captured = verify(
        () => repo.update(
          'a',
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: captureAny(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).captured;
      expect(captured.single, newDate);
    });

    test('surfaces ItemException as error state', () async {
      when(
        () => repo.update(
          any(),
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenThrow(ItemException('update_failed', 'boom'));

      final c = makeContainer();
      addTearDown(c.dispose);

      await c
          .read(itemFormControllerProvider.notifier)
          .submitEdit('a', name: 'x');

      expect(c.read(itemFormControllerProvider).hasError, isTrue);
    });
  });

  group('clearError', () {
    test('resets state to AsyncData(null) after a failed submit', () async {
      when(
        () => repo.add(
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).thenThrow(ItemException('add_failed', 'boom'));

      final c = makeContainer();
      addTearDown(c.dispose);

      await c
          .read(itemFormControllerProvider.notifier)
          .submitNew(
            name: 'x',
            category: ItemCategory.other,
            dateType: ItemDateType.due,
            targetDate: DateTime.utc(2026, 6, 1),
          );
      expect(c.read(itemFormControllerProvider).hasError, isTrue);

      c.read(itemFormControllerProvider.notifier).clearError();
      expect(c.read(itemFormControllerProvider).hasError, isFalse);
    });
  });
}
