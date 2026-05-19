import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/features/items/ui/widgets/amount_field.dart';

Widget _wrap(Widget child, [GlobalKey<FormState>? formKey]) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(key: formKey, child: child),
      ),
    ),
  );
}

void main() {
  group('AmountField', () {
    testWidgets('initial=null renders empty', (tester) async {
      await tester.pumpWidget(
        _wrap(AmountField(initialMinor: null, onChanged: (_) {})),
      );
      expect(find.text('₱'), findsOneWidget); // prefix
      // No decimal value pre-filled.
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text ?? '', '');
    });

    testWidgets('initial=1234 renders 12.34', (tester) async {
      await tester.pumpWidget(
        _wrap(AmountField(initialMinor: 1234, onChanged: (_) {})),
      );
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, '12.34');
    });

    testWidgets('typing 99.99 emits 9999 via onChanged', (tester) async {
      int? captured = -1;
      await tester.pumpWidget(
        _wrap(AmountField(initialMinor: null, onChanged: (m) => captured = m)),
      );
      await tester.enterText(find.byType(TextFormField), '99.99');
      await tester.pump();
      expect(captured, 9999);
    });

    testWidgets('typing an empty string emits null via onChanged', (
      tester,
    ) async {
      int? captured = -1;
      await tester.pumpWidget(
        _wrap(AmountField(initialMinor: 100, onChanged: (m) => captured = m)),
      );
      await tester.enterText(find.byType(TextFormField), '');
      await tester.pump();
      expect(captured, isNull);
    });

    testWidgets('letters are stripped at keypress (defense in depth)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(AmountField(initialMinor: null, onChanged: (_) {})),
      );
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.pump();
      // The FilteringTextInputFormatter dropped the letters; field is empty.
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller?.text, '');
    });

    testWidgets('malformed decimal "1.2.3" fails validation', (tester) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(AmountField(initialMinor: null, onChanged: (_) {}), formKey),
      );
      await tester.enterText(find.byType(TextFormField), '1.2.3');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Enter a valid amount'), findsOneWidget);
    });

    testWidgets('empty input passes validation (amount is optional)', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        _wrap(AmountField(initialMinor: null, onChanged: (_) {}), formKey),
      );
      expect(formKey.currentState!.validate(), isTrue);
    });
  });
}
