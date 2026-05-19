import 'package:intl/intl.dart';

/// PHP currency formatting helpers.
///
/// Amounts are stored as minor units (centavos) in the database to avoid
/// floating-point rounding errors. UI formats via [pesoFromMinor];
/// form input parses via [minorFromDecimal].
final NumberFormat _phpFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

/// Format a stored minor-unit amount for display.
/// Returns an empty string when [minor] is null so callers can show
/// nothing for items without an amount.
String pesoFromMinor(int? minor) {
  if (minor == null) return '';
  return _phpFormat.format(minor / 100);
}

/// Parse user-typed decimal input ("12.34", "12", "  12.50  ") into
/// stored minor units. Returns null for empty / non-numeric input;
/// rounds half-cent values to the nearest centavo.
int? minorFromDecimal(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final v = double.tryParse(trimmed);
  if (v == null) return null;
  return (v * 100).round();
}
