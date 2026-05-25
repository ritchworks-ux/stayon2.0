import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

/// Fixed V1 categories. Stored as `dbValue` strings in Postgres
/// (see migration 0002_items.sql CHECK constraint).
enum ItemCategory {
  warranty(
    'warranty',
    'Warranty',
    AppColors.catWarranty,
    AppColors.catWarrantyDark,
    Icons.shield_outlined,
  ),
  subscription(
    'subscription',
    'Subscription',
    AppColors.catSubscription,
    AppColors.catSubscriptionDark,
    Icons.subscriptions_outlined,
  ),
  idLicense(
    'id_license',
    'ID / License',
    AppColors.catDocument,
    AppColors.catDocumentDark,
    Icons.badge_outlined,
  ),
  insurance(
    'insurance',
    'Insurance',
    AppColors.catInsurance,
    AppColors.catInsuranceDark,
    Icons.health_and_safety_outlined,
  ),
  medicine(
    'medicine',
    'Medicine',
    AppColors.catMedicine,
    AppColors.catMedicineDark,
    Icons.medication_outlined,
  ),
  grocery(
    'grocery',
    'Grocery',
    AppColors.catGrocery,
    AppColors.catGroceryDark,
    Icons.local_grocery_store_outlined,
  ),
  bill(
    'bill',
    'Bill',
    AppColors.catBill,
    AppColors.catBillDark,
    Icons.receipt_long_outlined,
  ),
  document(
    'document',
    'Document',
    AppColors.catDocument,
    AppColors.catDocumentDark,
    Icons.description_outlined,
  ),
  other(
    'other',
    'Other',
    AppColors.catOther,
    AppColors.catOtherDark,
    Icons.label_outline,
  );

  const ItemCategory(
    this.dbValue,
    this.label,
    this.surface,
    this.darkSurface,
    this.icon,
  );

  final String dbValue;
  final String label;

  /// Light-mode category card background.
  final Color surface;

  /// Dark-mode category card background.
  final Color darkSurface;

  final IconData icon;

  /// Returns [darkSurface] in dark mode, [surface] otherwise.
  Color surfaceFor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : surface;
  }

  static ItemCategory fromDb(String value) => ItemCategory.values.firstWhere(
    (c) => c.dbValue == value,
    orElse: () => ItemCategory.other,
  );
}
