import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/money.dart';

void main() {
  group('pesoFromMinor', () {
    test('null minor returns empty string', () {
      expect(pesoFromMinor(null), '');
    });
    test('0 minor formats as ₱0.00', () {
      expect(pesoFromMinor(0), '₱0.00');
    });
    test('1234 minor formats as ₱12.34', () {
      expect(pesoFromMinor(1234), '₱12.34');
    });
    test('9_999_999 minor formats as ₱99,999.99', () {
      expect(pesoFromMinor(9999999), '₱99,999.99');
    });
    test('negative minor formats with sign (defensive)', () {
      expect(pesoFromMinor(-1234), startsWith('-₱'));
    });
  });

  group('minorFromDecimal', () {
    test('empty string returns null', () {
      expect(minorFromDecimal(''), null);
      expect(minorFromDecimal('   '), null);
    });
    test('12.34 parses to 1234', () {
      expect(minorFromDecimal('12.34'), 1234);
    });
    test('integer "12" parses to 1200', () {
      expect(minorFromDecimal('12'), 1200);
    });
    test('non-numeric returns null', () {
      expect(minorFromDecimal('abc'), null);
      expect(minorFromDecimal('12.34abc'), null);
    });
    test('rounds half-cent values', () {
      expect(minorFromDecimal('12.345'), 1235);
      expect(minorFromDecimal('12.344'), 1234);
    });
    test('handles leading/trailing whitespace', () {
      expect(minorFromDecimal('  12.34  '), 1234);
    });
  });
}
