// Regression test for Batch D bug #1/2: the Undo button on the
// archive/trash snackbar didn't fire because the SnackBarAction closure
// captured the detail screen's WidgetRef, which became defunct after
// `router.go('/home')` unmounted the screen. The fix captures the
// notifier instance pre-await; this test exercises the full flow to
// guarantee Undo still calls restore() after navigation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/controllers/item_providers.dart';
import 'package:stayon/features/items/data/item_repository.dart';
import 'package:stayon/features/items/ui/item_detail_screen.dart';

class _MockRepo extends Mock implements ItemRepository {}

Item _stub({String id = 'i', ItemStatus status = ItemStatus.active}) => Item(
  id: id,
  ownerId: 'o',
  name: 'PhilHealth ID',
  category: ItemCategory.idLicense,
  dateType: ItemDateType.renews,
  targetDate: DateTime.utc(2026, 12, 31),
  currencyCode: 'PHP',
  status: status,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

/// Minimal router that mirrors the production layout: a Home screen
/// the user is sent to AFTER archive/trash, and a detail screen
/// reached at /item/:id. We deliberately do NOT use a Scaffold for the
/// "Home" route so the snackbar is unambiguously owned by the root
/// ScaffoldMessenger (same as production via MaterialApp).
GoRouter _testRouter() => GoRouter(
  initialLocation: '/item/abc',
  routes: [
    GoRoute(
      path: '/home',
      builder: (_, _) => const Scaffold(body: Center(child: Text('HOME'))),
    ),
    GoRoute(
      path: '/item/:id',
      builder: (_, state) => ItemDetailScreen(id: state.pathParameters['id']!),
    ),
  ],
);

void main() {
  late _MockRepo repo;
  setUp(() {
    repo = _MockRepo();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    // Tall surface so the action row + dialogs fit in the same frame.
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [itemRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp.router(routerConfig: _testRouter()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('Item Detail shows Edit + Archive + Delete but NOT Mark renewed '
      '(Phase 2 simplification)', (tester) async {
    when(() => repo.getById('abc')).thenAnswer((_) async => _stub(id: 'abc'));
    when(() => repo.fetchActive()).thenAnswer((_) async => []);

    await pumpApp(tester);

    expect(find.widgetWithText(FilledButton, 'Edit'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Archive'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Delete'), findsOneWidget);
    expect(find.text('Mark renewed'), findsNothing);
  });

  testWidgets(
    'Archive -> snackbar Undo still calls restore after navigating to /home',
    (tester) async {
      when(() => repo.getById('abc')).thenAnswer((_) async => _stub(id: 'abc'));
      when(() => repo.fetchActive()).thenAnswer((_) async => []);
      when(
        () => repo.archive('abc'),
      ).thenAnswer((_) async => _stub(id: 'abc', status: ItemStatus.archived));
      when(() => repo.restore('abc')).thenAnswer((_) async => _stub(id: 'abc'));

      await pumpApp(tester);

      // Tap Archive
      await tester.tap(find.widgetWithText(OutlinedButton, 'Archive'));
      await tester.pumpAndSettle();

      // Confirm dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Archive'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Detail screen unmounted; we're on the Home route now.
      expect(find.text('HOME'), findsOneWidget);

      // The snackbar persists across the route change (root
      // ScaffoldMessenger). Tap its Undo action.
      expect(find.text('Item archived.'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      verify(() => repo.restore('abc')).called(1);
    },
  );

  testWidgets(
    'Delete -> snackbar Restore still calls restore after navigating to /home',
    (tester) async {
      when(() => repo.getById('abc')).thenAnswer((_) async => _stub(id: 'abc'));
      when(() => repo.fetchActive()).thenAnswer((_) async => []);
      when(
        () => repo.trash('abc'),
      ).thenAnswer((_) async => _stub(id: 'abc', status: ItemStatus.trashed));
      when(() => repo.restore('abc')).thenAnswer((_) async => _stub(id: 'abc'));

      await pumpApp(tester);

      // Tap Delete
      await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Confirm dialog
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('HOME'), findsOneWidget);
      expect(find.text('Item moved to Trash.'), findsOneWidget);

      await tester.tap(find.widgetWithText(SnackBarAction, 'Restore'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      verify(() => repo.restore('abc')).called(1);
    },
  );
}
