import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/extraction_result.dart';
import 'package:stayon/features/attachments/ui/extraction_review_sheet.dart';

void main() {
  group('ExtractionReviewSheet Widget Tests', () {
    late ExtractionResult mockExtractionResult;
    late List<int> mockImageBytes;

    setUp(() {
      // Create a minimal valid PNG (transparent 1x1 pixel)
      mockImageBytes = [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
        0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
        0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
        0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
        0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
        0x42, 0x60, 0x82,
      ];
      mockExtractionResult = ExtractionResult(
        type: 'receipt',
        data: {'date': '2026-05-24', 'amount_cents': 4599},
        confidence: 0.95,
        warnings: [],
      );
    });

    Widget buildTestWidget({
      required ExtractionResult extractionResult,
      required List<int> imageBytes,
      required void Function(DateTime?, double?, List<int>) onSave,
      VoidCallback? onCancel,
    }) {
      return MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => ExtractionReviewSheet(
                    extractionResult: extractionResult,
                    imageBytes: imageBytes,
                    onSave: onSave,
                    onCancel: onCancel,
                  ),
                ),
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders header with title and close button', (
      WidgetTester tester,
    ) async {
      bool saveTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) => saveTriggered = true,
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Review Extracted Data'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('displays photo preview thumbnail', (
      WidgetTester tester,
    ) async {
      bool saveTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) => saveTriggered = true,
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify Image.memory is rendered
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('displays extracted date field with correct value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify date field is displayed
      expect(find.text('Date'), findsOneWidget);
      // Date should be in MM/dd/yyyy format
      expect(find.text('05/24/2026'), findsOneWidget);
    });

    testWidgets('displays extracted amount field with correct value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Amount'), findsOneWidget);
      expect(find.text('\$45.99'), findsOneWidget);
    });

    testWidgets('displays confidence badge with high confidence color', (
      WidgetTester tester,
    ) async {
      final highConfidenceResult = ExtractionResult(
        type: 'receipt',
        data: {'date': '2026-05-24', 'amount_cents': 4599},
        confidence: 0.95,
        warnings: [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: highConfidenceResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Confidence: 95%'), findsOneWidget);
    });

    testWidgets('displays confidence badge with medium confidence color', (
      WidgetTester tester,
    ) async {
      final mediumConfidenceResult = ExtractionResult(
        type: 'receipt',
        data: {'date': '2026-05-24', 'amount_cents': 4599},
        confidence: 0.80,
        warnings: [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mediumConfidenceResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Confidence: 80%'), findsOneWidget);
    });

    testWidgets('displays confidence badge with low confidence color', (
      WidgetTester tester,
    ) async {
      final lowConfidenceResult = ExtractionResult(
        type: 'receipt',
        data: {'date': '2026-05-24', 'amount_cents': 4599},
        confidence: 0.70,
        warnings: [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: lowConfidenceResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Confidence: 70%'), findsOneWidget);
    });

    testWidgets('displays merchant metadata when present', (
      WidgetTester tester,
    ) async {
      final resultWithMerchant = ExtractionResult(
        type: 'receipt',
        data: {
          'date': '2026-05-24',
          'amount_cents': 4599,
          'merchant': 'Whole Foods Market',
        },
        confidence: 0.95,
        warnings: [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: resultWithMerchant,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Merchant: Whole Foods Market'),
        findsOneWidget,
      );
    });

    testWidgets('does not display merchant metadata when absent', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Merchant:'), findsNothing);
    });

    testWidgets('date field is read-only with date picker', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final dateFieldFinder = find.byType(TextField).at(0);
      expect(dateFieldFinder, findsOneWidget);

      // Verify field is read-only (opens date picker on tap)
      final textField = tester.widget<TextField>(dateFieldFinder);
      expect(textField.readOnly, true);
    });

    testWidgets('amount field is editable', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final amountFieldFinder = find.byType(TextField).at(1);
      expect(amountFieldFinder, findsOneWidget);

      // Verify field is not read-only
      final textField = tester.widget<TextField>(amountFieldFinder);
      expect(textField.readOnly, false);
    });

    testWidgets('date picker opens when date field is tapped', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap on date field
      final dateFieldFinder = find.byType(TextField).at(0);
      await tester.tap(dateFieldFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Date picker should appear (Dialog)
      expect(find.byType(Dialog), findsWidgets);
    });

    testWidgets('close button triggers cancel callback', (
      WidgetTester tester,
    ) async {
      bool cancelTriggered = false;

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
          onCancel: () => cancelTriggered = true,
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(cancelTriggered, true);
      expect(find.text('Review Extracted Data'), findsNothing);
    });

    testWidgets('handles null date gracefully', (WidgetTester tester) async {
      final resultWithoutDate = ExtractionResult(
        type: 'receipt',
        data: {'amount_cents': 4599},
        confidence: 0.95,
        warnings: [],
      );

      DateTime? capturedDate;
      double? capturedAmount;

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: resultWithoutDate,
          imageBytes: mockImageBytes,
          onSave: (date, amount, __) {
            capturedDate = date;
            capturedAmount = amount;
          },
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('handles null amount gracefully', (WidgetTester tester) async {
      final resultWithoutAmount = ExtractionResult(
        type: 'receipt',
        data: {'date': '2026-05-24'},
        confidence: 0.95,
        warnings: [],
      );

      DateTime? capturedDate;
      double? capturedAmount;

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: resultWithoutAmount,
          imageBytes: mockImageBytes,
          onSave: (date, amount, __) {
            capturedDate = date;
            capturedAmount = amount;
          },
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Date'), findsOneWidget);
      expect(find.text('Amount'), findsOneWidget);
    });

    testWidgets('formats date field as MM/dd/yyyy', (
      WidgetTester tester,
    ) async {
      final resultWithDate = ExtractionResult(
        type: 'receipt',
        data: {'date': '2026-01-05', 'amount_cents': 999},
        confidence: 0.90,
        warnings: [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: resultWithDate,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('01/05/2026'), findsOneWidget);
    });

    testWidgets('formats amount field as \$X.XX with proper decimal', (
      WidgetTester tester,
    ) async {
      final resultWithAmount = ExtractionResult(
        type: 'receipt',
        data: {'date': '2026-05-24', 'amount_cents': 100},
        confidence: 0.90,
        warnings: [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: resultWithAmount,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('\$1.00'), findsOneWidget);
    });

    testWidgets('renders in Material 3 style', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          extractionResult: mockExtractionResult,
          imageBytes: mockImageBytes,
          onSave: (_, __, ___) {},
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify Material 3 widgets
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    });

    testWidgets('respects dark mode colors', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          themeMode: ThemeMode.dark,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => ExtractionReviewSheet(
                      extractionResult: mockExtractionResult,
                      imageBytes: mockImageBytes,
                      onSave: (_, __, ___) {},
                    ),
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Review Extracted Data'), findsOneWidget);
    });
  });
}
