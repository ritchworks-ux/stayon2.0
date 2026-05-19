import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/app/theme/colors.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/ui/widgets/item_card.dart';

DateTime _d(int y, int m, int day) => DateTime.utc(y, m, day);

Item _stub({
  String name = 'Test',
  ItemCategory category = ItemCategory.idLicense,
  DateTime? targetDate,
  String? notes,
  String? assigneeLabel,
  int? amountMinor,
}) => Item(
  id: 'i',
  ownerId: 'o',
  name: name,
  category: category,
  dateType: ItemDateType.expires,
  targetDate: targetDate ?? _d(2026, 12, 31),
  notes: notes,
  assigneeLabel: assigneeLabel,
  amountMinor: amountMinor,
  currencyCode: 'PHP',
  status: ItemStatus.active,
  createdAt: _d(2026, 1, 1),
  updatedAt: _d(2026, 1, 1),
);

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  group('ItemCard', () {
    testWidgets('renders name, uppercased category label, and relative date', (
      tester,
    ) async {
      final now = _d(2026, 5, 18);
      await tester.pumpWidget(
        _wrap(
          ItemCard(
            item: _stub(
              name: 'PhilHealth ID',
              category: ItemCategory.idLicense,
              targetDate: _d(2026, 5, 21),
            ),
            now: now,
          ),
        ),
      );

      expect(find.text('PhilHealth ID'), findsOneWidget);
      expect(find.text('ID / LICENSE'), findsOneWidget);
      expect(find.text('Due in 3 days'), findsOneWidget);
    });

    testWidgets('shows amount when present, hides when null', (tester) async {
      final now = _d(2026, 5, 18);
      await tester.pumpWidget(
        _wrap(
          ItemCard(
            item: _stub(amountMinor: 250000, targetDate: now),
            now: now,
          ),
        ),
      );
      expect(find.text('₱2,500.00'), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          ItemCard(
            item: _stub(amountMinor: null, targetDate: now),
            now: now,
          ),
        ),
      );
      expect(find.textContaining('₱'), findsNothing);
    });

    testWidgets('shows assignee when present, hides when null', (tester) async {
      final now = _d(2026, 5, 18);
      await tester.pumpWidget(
        _wrap(
          ItemCard(
            item: _stub(assigneeLabel: 'Mom', targetDate: now),
            now: now,
          ),
        ),
      );
      expect(find.text('Mom'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      await tester.pumpWidget(
        _wrap(
          ItemCard(
            item: _stub(assigneeLabel: null, targetDate: now),
            now: now,
          ),
        ),
      );
      expect(find.byIcon(Icons.person_outline), findsNothing);
    });

    testWidgets('tap fires the onTap callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(ItemCard(item: _stub(), onTap: () => taps++)),
      );

      await tester.tap(find.byType(ItemCard));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('overdue items render the relative-date label in coral', (
      tester,
    ) async {
      final now = _d(2026, 5, 18);
      await tester.pumpWidget(
        _wrap(
          ItemCard(
            item: _stub(targetDate: _d(2026, 5, 10)),
            now: now,
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Overdue by 8 days'));
      expect(text.style?.color, AppColors.coral);
      expect(text.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('accessibility label includes name, category, and date', (
      tester,
    ) async {
      final now = _d(2026, 5, 18);
      await tester.pumpWidget(
        _wrap(
          ItemCard(
            item: _stub(
              name: 'PhilHealth',
              category: ItemCategory.idLicense,
              targetDate: _d(2026, 5, 21),
              assigneeLabel: 'Mom',
              amountMinor: 250000,
            ),
            now: now,
          ),
        ),
      );

      final node = tester.getSemantics(find.byType(ItemCard));
      expect(node.label, contains('PhilHealth'));
      expect(node.label, contains('ID / License'));
      expect(node.label, contains('Due in 3 days'));
      expect(node.label, contains('Mom'));
      expect(node.label, contains('₱2,500.00'));
    });
  });
}
