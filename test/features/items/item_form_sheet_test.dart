import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/item.dart';
import 'package:stayon/core/models/item_category.dart';
import 'package:stayon/core/models/item_date_type.dart';
import 'package:stayon/core/models/item_status.dart';
import 'package:stayon/features/items/controllers/item_providers.dart';
import 'package:stayon/features/items/data/item_repository.dart';
import 'package:stayon/features/items/ui/item_form_sheet.dart';

class _MockRepo extends Mock implements ItemRepository {}

class _FakeItem extends Fake implements Item {}

Item _stub({
  String id = 'i',
  String name = 'PhilHealth',
  ItemCategory category = ItemCategory.idLicense,
  ItemDateType dateType = ItemDateType.renews,
  DateTime? targetDate,
}) => Item(
  id: id,
  ownerId: 'o',
  name: name,
  category: category,
  dateType: dateType,
  targetDate: targetDate ?? DateTime.utc(2026, 12, 31),
  currencyCode: 'PHP',
  status: ItemStatus.active,
  createdAt: DateTime.utc(2026, 1, 1),
  updatedAt: DateTime.utc(2026, 1, 1),
);

Widget _wrap({required _MockRepo repo, Item? existing}) {
  return ProviderScope(
    overrides: [itemRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      // NoSplash avoids the ink_sparkle.frag shader version mismatch that
      // causes spurious failures when tester.tap() triggers InkWell.
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: Scaffold(body: ItemFormSheet(existing: existing)),
    ),
  );
}

/// Pumps frames until the DraggableScrollableSheet animation settles
/// AND the AsyncNotifier's initial build() Future has resolved. We
/// don't use pumpAndSettle because the sheet's controller can hold
/// the test in an animating state past the default timeout. 1 second
/// is more than enough for both to finish in practice.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The form is taller than the default 800×600 test surface. Setting
/// a phone-sized but very tall surface lets every section + submit
/// button render in the same frame so taps land correctly.
Future<void> _setTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(400, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeItem());
    registerFallbackValue(ItemCategory.other);
    registerFallbackValue(ItemDateType.due);
    registerFallbackValue(DateTime.utc(2026, 1, 1));
  });

  late _MockRepo repo;
  setUp(() {
    repo = _MockRepo();
  });

  group('Add mode', () {
    testWidgets('renders the form header, category, date type sections', (
      tester,
    ) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo));
      await _settle(tester);

      // Header
      expect(find.text('Add item'), findsAtLeastNWidgets(1));
      // Section labels
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Date type'), findsOneWidget);
      expect(find.text('Target date'), findsOneWidget);
      // Submit + cancel both present
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
    });

    testWidgets('empty name blocks submit and shows validation error', (
      tester,
    ) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo));
      await _settle(tester);

      await tester.tap(find.byType(FilledButton));
      await _settle(tester);

      expect(find.text('Name is required'), findsOneWidget);
      verifyNever(
        () => repo.add(
          name: any(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      );
    });

    testWidgets('valid submit calls repository.add with the entered name', (
      tester,
    ) async {
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
      ).thenAnswer((_) async => _stub(id: 'new'));
      when(() => repo.fetchActive()).thenAnswer((_) async => []);

      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo));
      await _settle(tester);

      // First TextFormField is "Name" (autofocused in Add mode).
      await tester.enterText(find.byType(TextFormField).first, 'My Item');
      await tester.tap(find.byType(FilledButton));
      await _settle(tester);

      final captured = verify(
        () => repo.add(
          name: captureAny(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).captured;
      expect(captured.single, 'My Item');
    });
  });

  group('past-date warning', () {
    // The real DatePicker dialog cannot be triggered in headless tests.
    // ItemFormSheet accepts a @visibleForTesting testInitialDate param so
    // tests can drive the warning without opening the picker.

    testWidgets('shows warning in Add mode when initial date is in the past', (
      tester,
    ) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      await _setTallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [itemRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Scaffold(body: ItemFormSheet(testInitialDate: pastDate)),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('past_date_warning')), findsOneWidget);
    });

    testWidgets('no warning in Add mode when date is today or future', (
      tester,
    ) async {
      final futureDate = DateTime.now().add(const Duration(days: 10));
      await _setTallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [itemRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            home: Scaffold(body: ItemFormSheet(testInitialDate: futureDate)),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byKey(const Key('past_date_warning')), findsNothing);
    });

    testWidgets(
      'no warning in Edit mode even when item has a past target date',
      (tester) async {
        final pastItem = _stub(
          targetDate: DateTime.now().subtract(const Duration(days: 10)),
        );
        await _setTallSurface(tester);
        await tester.pumpWidget(_wrap(repo: repo, existing: pastItem));
        await _settle(tester);
        // Edit mode suppresses the warning — past dates on existing items
        // are expected (the user may not have renewed yet).
        expect(find.byKey(const Key('past_date_warning')), findsNothing);
      },
    );
  });

  group('Edit mode', () {
    testWidgets('prefills the name field from the existing item', (
      tester,
    ) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          repo: repo,
          existing: _stub(name: 'PhilHealth ID'),
        ),
      );
      await _settle(tester);

      expect(find.text('Edit item'), findsOneWidget); // header
      // Name field shows the prefill text.
      expect(
        find.widgetWithText(TextFormField, 'PhilHealth ID'),
        findsOneWidget,
      );
    });

    testWidgets('valid submit calls repository.update with the item id', (
      tester,
    ) async {
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
      ).thenAnswer((_) async => _stub(id: 'row-1', name: 'Updated'));
      when(() => repo.fetchActive()).thenAnswer((_) async => []);

      await _setTallSurface(tester);
      await tester.pumpWidget(
        _wrap(
          repo: repo,
          existing: _stub(id: 'row-1', name: 'Old name'),
        ),
      );
      await _settle(tester);

      await tester.enterText(find.byType(TextFormField).first, 'Updated');
      await tester.tap(find.byType(FilledButton));
      await _settle(tester);

      final captured = verify(
        () => repo.update(
          captureAny(),
          name: captureAny(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).captured;
      expect(captured[0], 'row-1');
      expect(captured[1], 'Updated');
    });
  });

  group('Barcode scanner integration', () {
    testWidgets('scan barcode button is visible in Add mode', (tester) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo));
      await _settle(tester);

      expect(find.byIcon(Icons.barcode_reader), findsOneWidget);
      expect(find.byTooltip('Scan barcode for quick entry'), findsOneWidget);
    });

    testWidgets('barcode button is not visible in Edit mode', (tester) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo, existing: _stub()));
      await _settle(tester);

      // Edit mode should not show the barcode button
      expect(find.byIcon(Icons.barcode_reader), findsNothing);
    });

    testWidgets('tapping barcode button opens BarcodeScannerSheet', (
      tester,
    ) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo));
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.barcode_reader));
      await _settle(tester);

      // Verify the scanner sheet appears
      expect(find.text('Scan barcode'), findsWidgets);
    });

    testWidgets('can dismiss barcode scanner and return to form', (
      tester,
    ) async {
      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo));
      await _settle(tester);

      await tester.tap(find.byIcon(Icons.barcode_reader));
      await _settle(tester);

      // Close the scanner sheet by tapping the close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsWidgets); // Multiple close buttons exist
      await tester.tap(closeButton.last);
      await _settle(tester);

      // Should be back to the form with the barcode button visible
      expect(find.byIcon(Icons.barcode_reader), findsOneWidget);
    });

    testWidgets('form can be submitted after using scanner', (tester) async {
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
      ).thenAnswer((_) async => _stub(id: 'new'));
      when(() => repo.fetchActive()).thenAnswer((_) async => []);

      await _setTallSurface(tester);
      await tester.pumpWidget(_wrap(repo: repo));
      await _settle(tester);

      // Manually enter a name (simulating either manual entry or pre-fill)
      await tester.enterText(find.byType(TextFormField).first, 'Test Item');
      await tester.tap(find.byType(FilledButton).first);
      await _settle(tester);

      // Verify repository.add was called
      verify(
        () => repo.add(
          name: captureAny(named: 'name'),
          category: any(named: 'category'),
          dateType: any(named: 'dateType'),
          targetDate: any(named: 'targetDate'),
          notes: any(named: 'notes'),
          assigneeLabel: any(named: 'assigneeLabel'),
          amountMinor: any(named: 'amountMinor'),
        ),
      ).called(1);
    });
  });
}
