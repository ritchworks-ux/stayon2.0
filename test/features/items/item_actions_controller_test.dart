import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/controllers/item_actions_controller.dart';
import 'package:stayon/features/items/controllers/item_providers.dart';
import 'package:stayon/features/items/data/item_repository.dart';

class _MockRepo extends Mock implements ItemRepository {}

Item _stub({String id = 'i', ItemStatus status = ItemStatus.active}) => Item(
  id: id,
  ownerId: 'o',
  name: 'X',
  category: ItemCategory.other,
  dateType: ItemDateType.expires,
  targetDate: DateTime.utc(2026, 6, 1),
  currencyCode: 'PHP',
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [itemRepositoryProvider.overrideWithValue(repo)],
  );

  group('archive', () {
    test(
      'calls repo.archive, returns the updated item, invalidates list',
      () async {
        var fetchCount = 0;
        when(() => repo.fetchActive()).thenAnswer((_) async {
          fetchCount++;
          return [_stub(id: 'a')];
        });
        when(
          () => repo.archive('a'),
        ).thenAnswer((_) async => _stub(id: 'a', status: ItemStatus.archived));

        final c = makeContainer();
        addTearDown(c.dispose);

        await c.read(itemsProvider.future);
        expect(fetchCount, 1);

        final updated = await c
            .read(itemActionsControllerProvider.notifier)
            .archive('a');

        expect(updated, isNotNull);
        expect(updated!.status, ItemStatus.archived);
        verify(() => repo.archive('a')).called(1);

        // itemsProvider invalidated -> next read re-fetches
        await c.read(itemsProvider.future);
        expect(fetchCount, 2);
      },
    );

    test('surfaces ItemException as error state and returns null', () async {
      when(() => repo.archive('a')).thenThrow(ItemException('rls', 'denied'));

      final c = makeContainer();
      addTearDown(c.dispose);

      final updated = await c
          .read(itemActionsControllerProvider.notifier)
          .archive('a');

      expect(updated, isNull);
      final s = c.read(itemActionsControllerProvider);
      expect(s.hasError, isTrue);
      expect((s.error! as ItemException).code, 'rls');
    });
  });

  group('trash', () {
    test('calls repo.trash and invalidates list', () async {
      when(() => repo.fetchActive()).thenAnswer((_) async => []);
      when(
        () => repo.trash('a'),
      ).thenAnswer((_) async => _stub(id: 'a', status: ItemStatus.trashed));

      final c = makeContainer();
      addTearDown(c.dispose);

      final updated = await c
          .read(itemActionsControllerProvider.notifier)
          .trash('a');

      expect(updated!.status, ItemStatus.trashed);
      verify(() => repo.trash('a')).called(1);
    });
  });

  group('restore', () {
    test('calls repo.restore and returns active item', () async {
      when(() => repo.fetchActive()).thenAnswer((_) async => []);
      when(() => repo.restore('a')).thenAnswer((_) async => _stub(id: 'a'));

      final c = makeContainer();
      addTearDown(c.dispose);

      final updated = await c
          .read(itemActionsControllerProvider.notifier)
          .restore('a');

      expect(updated!.status, ItemStatus.active);
      verify(() => repo.restore('a')).called(1);
    });
  });

  group('clear', () {
    test('resets state to AsyncData(null) after an error', () async {
      when(() => repo.archive(any())).thenThrow(ItemException('boom', 'x'));

      final c = makeContainer();
      addTearDown(c.dispose);

      await c.read(itemActionsControllerProvider.notifier).archive('a');
      expect(c.read(itemActionsControllerProvider).hasError, isTrue);

      c.read(itemActionsControllerProvider.notifier).clear();
      expect(c.read(itemActionsControllerProvider).hasError, isFalse);
    });
  });
}
