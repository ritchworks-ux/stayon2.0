import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/main.dart';

void main() {
  testWidgets('Placeholder home renders tagline', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayOnApp()));
    expect(find.text('Never miss what matters.'), findsOneWidget);
    expect(find.text('StayOn'), findsOneWidget);
  });
}
