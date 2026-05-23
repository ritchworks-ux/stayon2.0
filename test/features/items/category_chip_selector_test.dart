import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/features/items/ui/widgets/category_chip.dart';
import 'package:stayon/features/items/ui/widgets/category_chip_selector.dart';

Widget _wrap(Widget child) => MaterialApp(
  // NoSplash avoids the ink_sparkle.frag shader version mismatch that
  // causes spurious failures when tester.tap() triggers InkWell.
  theme: ThemeData(splashFactory: NoSplash.splashFactory),
  home: Scaffold(
    body: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

void main() {
  group('CategoryChip', () {
    testWidgets('renders icon + label for the given category', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CategoryChip(
            category: ItemCategory.medicine,
            selected: false,
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Medicine'), findsOneWidget);
      expect(find.byIcon(Icons.medication_outlined), findsOneWidget);
    });

    testWidgets('selected chip shows a check icon (color-blind safe)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const CategoryChip(category: ItemCategory.bill, selected: true)),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('unselected chip does NOT show a check icon', (tester) async {
      await tester.pumpWidget(
        _wrap(const CategoryChip(category: ItemCategory.bill, selected: false)),
      );

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('tap calls onTap callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          CategoryChip(
            category: ItemCategory.grocery,
            selected: false,
            onTap: () => taps++,
          ),
        ),
      );

      await tester.tap(find.byType(CategoryChip));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('disabled (onTap=null) does not respond to tap', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryChip(category: ItemCategory.grocery, selected: true),
        ),
      );

      // No callback wired, no exception should fire.
      await tester.tap(find.byType(CategoryChip));
      await tester.pump();
    });

    testWidgets('Semantics marks the chip as a selectable button', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const CategoryChip(category: ItemCategory.warranty, selected: true),
        ),
      );

      // The chip merges its outer Semantics with the inner Text. We don't
      // assert the exact label string (screen readers concatenate cleanly);
      // we verify the structural flags that matter for a11y.
      final node = tester.getSemantics(find.byType(CategoryChip));
      // Tristate for selected (true/false/unset), bool for isButton.
      expect(node.flagsCollection.isSelected, Tristate.isTrue);
      expect(node.flagsCollection.isButton, isTrue);
    });
  });

  group('CategoryChipSelector', () {
    testWidgets('renders all 9 categories', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CategoryChipSelector(selected: ItemCategory.other, onChanged: (_) {}),
        ),
      );

      expect(
        find.byType(CategoryChip),
        findsNWidgets(ItemCategory.values.length),
      );
      for (final c in ItemCategory.values) {
        expect(find.text(c.label), findsOneWidget);
      }
    });

    testWidgets('exactly one chip shows the selected state', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CategoryChipSelector(
            selected: ItemCategory.insurance,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('tapping an unselected chip emits its category', (
      tester,
    ) async {
      ItemCategory? lastEmitted;
      await tester.pumpWidget(
        _wrap(
          CategoryChipSelector(
            selected: ItemCategory.other,
            onChanged: (c) => lastEmitted = c,
          ),
        ),
      );

      await tester.tap(find.text('Bill'));
      await tester.pump();

      expect(lastEmitted, ItemCategory.bill);
    });

    testWidgets('tapping the already-selected chip does NOT emit', (
      tester,
    ) async {
      var emissions = 0;
      await tester.pumpWidget(
        _wrap(
          CategoryChipSelector(
            selected: ItemCategory.bill,
            onChanged: (_) => emissions++,
          ),
        ),
      );

      await tester.tap(find.text('Bill'));
      await tester.pump();

      expect(emissions, 0);
    });
  });
}
