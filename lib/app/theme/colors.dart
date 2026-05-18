import 'package:flutter/material.dart';

/// StayOn brand color tokens. Single source of truth for all UI colors.
abstract final class AppColors {
  // Brand
  static const forest = Color(0xFF0F3D2E);
  static const green = Color(0xFF1F7A4D);
  static const mint = Color(0xFFD6EBDD);
  static const cream = Color(0xFFFAF6EE);
  static const ink = Color(0xFF1A1A1A);

  // Accent
  static const coral = Color(0xFFFF7A5C);

  // Category surfaces
  static const catMedicine = Color(0xFFFFE3D8);
  static const catGrocery = Color(0xFFFFEAC2);
  static const catDocument = Color(0xFFDDEBFF);
  static const catSubscription = Color(0xFFD6EBDD);
  static const catWarranty = Color(0xFFEADBFF);
  static const catBill = Color(0xFFFFE0E6);
  static const catInsurance = Color(0xFFDDEBFF);
  static const catOther = Color(0xFFECECEC);

  // Dark mode
  static const darkBg = Color(0xFF0E1411);
  static const darkSurface = Color(0xFF16201B);
}
