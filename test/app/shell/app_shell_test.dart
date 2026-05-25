import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/app/shell/app_shell.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/controllers/item_providers.dart';
import 'package:stayon/features/items/data/item_repository.dart';

class _MockRepo extends Mock implements ItemRepository {}

Item _item({required String id, required DateTime targetDate}) => Item(
  id: id,
  ownerId: 'o',
  name: 'Test $id',
  category: ItemCategory.other,
  dateType: ItemDateType.expires,
  targetDate: targetDate,
  currencyCode: 'PHP',
  status: ItemStatus.active,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

/// Builds a minimal router that exercises AppShell via StatefulShellRoute.
/// The shell branches are stubs — only the NavigationBar is under test.
Widget _wrapWithRouter({required _MockRepo repo, required List<Item> items}) {
  when(() => repo.fetchActive()).thenAnswer((_) async => items);

  final router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/alerts',
                builder: (_, _) => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/family',
                builder: (_, _) => const Scaffold(body: SizedBox()),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  return ProviderScope(
    overrides: [itemRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp.router(routerConfig: router),
  );
}

/// Pumps enough frames for the FutureProvider to resolve and
/// the NavigationBar animation to settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  group('AppShell overdue badge', () {
    testWidgets('shows Badge label when items are overdue', (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 3));
      final items = [
        _item(id: 'a', targetDate: pastDate),
        _item(id: 'b', targetDate: pastDate),
      ];

      await tester.pumpWidget(_wrapWithRouter(repo: repo, items: items));
      await _settle(tester);

      // At least one Badge with a visible label must exist on the
      // Alerts nav icon once the overdue count is > 0.
      final badges = tester.widgetList<Badge>(find.byType(Badge)).toList();
      expect(
        badges.any((b) => b.label != null),
        isTrue,
        reason: 'Expected a Badge with a label when there are overdue items',
      );
    });

    testWidgets('no visible Badge when no items are overdue', (tester) async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      final items = [_item(id: 'a', targetDate: futureDate)];

      await tester.pumpWidget(_wrapWithRouter(repo: repo, items: items));
      await _settle(tester);

      final badges = tester.widgetList<Badge>(find.byType(Badge)).toList();
      final visible = badges.where((b) => b.label != null).toList();
      expect(
        visible,
        isEmpty,
        reason: 'No Badge label should show when 0 items are overdue',
      );
    });

    testWidgets('no visible Badge when item list is empty', (tester) async {
      await tester.pumpWidget(_wrapWithRouter(repo: repo, items: []));
      await _settle(tester);

      final badges = tester.widgetList<Badge>(find.byType(Badge)).toList();
      final visible = badges.where((b) => b.label != null).toList();
      expect(visible, isEmpty);
    });
  });
}
