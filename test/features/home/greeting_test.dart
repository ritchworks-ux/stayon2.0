import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/features/home/utils/greeting.dart';

void main() {
  group('greetingLine', () {
    test('morning before noon', () {
      expect(greetingLine(DateTime(2026, 5, 22, 0)), 'Good morning,');
      expect(greetingLine(DateTime(2026, 5, 22, 9)), 'Good morning,');
      expect(greetingLine(DateTime(2026, 5, 22, 11, 59)), 'Good morning,');
    });

    test('afternoon from noon to 17:59', () {
      expect(greetingLine(DateTime(2026, 5, 22, 12)), 'Good afternoon,');
      expect(greetingLine(DateTime(2026, 5, 22, 17, 59)), 'Good afternoon,');
    });

    test('evening from 18:00 onward', () {
      expect(greetingLine(DateTime(2026, 5, 22, 18)), 'Good evening,');
      expect(greetingLine(DateTime(2026, 5, 22, 23, 59)), 'Good evening,');
    });
  });
}
