import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/app_user.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/auth/controllers/auth_providers.dart';
import 'package:stayon/features/auth/data/auth_repository.dart';
import 'package:stayon/features/home/ui/home_screen.dart';
import 'package:stayon/features/items/controllers/item_providers.dart';
import 'package:stayon/features/items/data/item_repository.dart';
import 'package:stayon/features/items/ui/widgets/empty_home_state.dart';
import 'package:stayon/features/items/ui/widgets/item_card.dart';

class _MockAuthRepo extends Mock implements AuthRepository {}

class _MockItemRepo extends Mock implements ItemRepository {}

DateTime _d(int y, int m, int day) => DateTime.utc(y, m, day);

Item _stub({
  String id = 'i',
  String name = 'Test',
  ItemCategory category = ItemCategory.other,
  DateTime? targetDate,
}) => Item(
  id: id,
  ownerId: 'u',
  name: name,
  category: category,
  dateType: ItemDateType.expires,
  targetDate: targetDate ?? _d(2026, 6, 1),
  currencyCode: 'PHP',
  status: ItemStatus.active,
  createdAt: _d(2026, 1, 1),
  updatedAt: _d(2026, 1, 1),
);

Widget _wrap({
  required _MockAuthRepo authRepo,
  required _MockItemRepo itemRepo,
}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      itemRepositoryProvider.overrideWithValue(itemRepo),
    ],
    // Fixed morning clock keeps the greeting deterministic ("Good
    // morning,") and the date buckets stable regardless of run time.
    // NoSplash avoids the ink_sparkle.frag shader version mismatch that
    // causes spurious failures when tester.tap() triggers InkWell.
    child: MaterialApp(
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: HomeScreen(now: DateTime(2026, 5, 22, 9)),
    ),
  );
}

void main() {
  late _MockAuthRepo authRepo;
  late _MockItemRepo itemRepo;

  setUp(() {
    authRepo = _MockAuthRepo();
    itemRepo = _MockItemRepo();
    when(
      () => authRepo.currentUser,
    ).thenReturn(const AppUser(id: 'u', email: 'rohan@example.com'));
    when(() => authRepo.currentUserChanges()).thenAnswer(
      (_) => Stream<AppUser?>.value(
        const AppUser(id: 'u', email: 'rohan@example.com'),
      ),
    );
  });

  testWidgets('greets user by email prefix', (tester) async {
    when(() => itemRepo.fetchActive()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(authRepo: authRepo, itemRepo: itemRepo));
    await tester.pumpAndSettle();

    expect(find.text('rohan'), findsOneWidget);
    expect(find.text('Good morning,'), findsOneWidget);
  });

  testWidgets('loading state shows a CircularProgressIndicator', (
    tester,
  ) async {
    final completer = Completer<List<Item>>();
    when(() => itemRepo.fetchActive()).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(authRepo: authRepo, itemRepo: itemRepo));
    await tester.pump(); // first frame, fetch is pending

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete([]);
    await tester.pumpAndSettle();
  });

  testWidgets('empty list shows EmptyHomeState', (tester) async {
    when(() => itemRepo.fetchActive()).thenAnswer((_) async => []);

    await tester.pumpWidget(_wrap(authRepo: authRepo, itemRepo: itemRepo));
    await tester.pumpAndSettle();

    expect(find.byType(EmptyHomeState), findsOneWidget);
    expect(find.text('No items yet'), findsOneWidget);
  });

  testWidgets('error state shows retry button that re-invokes fetch', (
    tester,
  ) async {
    var calls = 0;
    when(() => itemRepo.fetchActive()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw ItemException('fetch_failed', 'boom');
      return [];
    });

    await tester.pumpWidget(_wrap(authRepo: authRepo, itemRepo: itemRepo));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your items"), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();

    // Retry triggered a second fetch, which returns [].
    expect(calls, 2);
    expect(find.byType(EmptyHomeState), findsOneWidget);
  });

  testWidgets('renders ItemCards bucketed into the right sections', (
    tester,
  ) async {
    final items = [
      _stub(id: 'overdue', name: 'Overdue One', targetDate: _d(2026, 5, 10)),
      _stub(id: 'thisweek', name: 'This Week', targetDate: _d(2026, 5, 22)),
      _stub(id: 'thismonth', name: 'This Month', targetDate: _d(2026, 6, 5)),
      _stub(id: 'later', name: 'Later One', targetDate: _d(2026, 9, 1)),
    ];
    when(() => itemRepo.fetchActive()).thenAnswer((_) async => items);

    await tester.pumpWidget(_wrap(authRepo: authRepo, itemRepo: itemRepo));
    await tester.pumpAndSettle();

    // Four item cards rendered (skipOffstage: false because hero + stat tiles
    // push some cards below the default test viewport).
    expect(find.byType(ItemCard, skipOffstage: false), findsNWidgets(4));
    // Section headers present (order matters: Overdue first).
    expect(find.text('Overdue', skipOffstage: false), findsOneWidget);
    expect(find.text('This week', skipOffstage: false), findsOneWidget);
    expect(find.text('This month', skipOffstage: false), findsOneWidget);
    expect(find.text('Later', skipOffstage: false), findsOneWidget);
    // Item names visible.
    expect(find.text('Overdue One', skipOffstage: false), findsOneWidget);
    expect(find.text('Later One', skipOffstage: false), findsOneWidget);

    // Verify "Overdue" header appears in the widget tree BEFORE "Later".
    // Use skipOffstage:false so we can measure items below the fold.
    final overdueTop = tester
        .getTopLeft(find.text('Overdue', skipOffstage: false))
        .dy;
    final laterTop = tester
        .getTopLeft(find.text('Later', skipOffstage: false))
        .dy;
    expect(overdueTop, lessThan(laterTop));
  });

  testWidgets('pull-to-refresh re-fetches items', (tester) async {
    var calls = 0;
    when(() => itemRepo.fetchActive()).thenAnswer((_) async {
      calls++;
      return [_stub(id: 'a', name: 'Card A')];
    });

    await tester.pumpWidget(_wrap(authRepo: authRepo, itemRepo: itemRepo));
    await tester.pumpAndSettle();

    expect(calls, 1);

    // Drag the list from top to trigger RefreshIndicator.
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(calls, greaterThanOrEqualTo(2));
  });

  // Note: tapping a card now navigates to `/item/:id` via `context.push`,
  // which is exercised end-to-end in the router test
  // (test/app/router/app_router_test.dart). Re-asserting navigation here
  // would require building MaterialApp.router with the full GoRouter,
  // which duplicates router-test coverage without adding value.
}
