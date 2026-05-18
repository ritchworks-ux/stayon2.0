import 'package:flutter/material.dart';

/// StayOn typography scale, all in Nunito Sans. Use these instead of raw TextStyles.
abstract final class AppTypography {
  static const _family = 'NunitoSans';

  static const displayLg = TextStyle(
    fontFamily: _family,
    fontSize: 34,
    height: 40 / 34,
    fontWeight: FontWeight.w900,
  );

  static const displayMd = TextStyle(
    fontFamily: _family,
    fontSize: 28,
    height: 34 / 28,
    fontWeight: FontWeight.w800,
  );

  static const titleLg = TextStyle(
    fontFamily: _family,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w800,
  );

  static const titleMd = TextStyle(
    fontFamily: _family,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w700,
  );

  static const bodyLg = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  static const bodyMd = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  );

  static const labelSm = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.72,
  );

  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
  );
}
