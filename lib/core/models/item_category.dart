import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

/// Fixed V1 categories. Stored as `dbValue` strings in Postgres
/// (see migration 0002_items.sql CHECK constraint).
enum ItemCategory {
  warranty(
    'warranty',
    'Warranty',
    AppColors.catWarranty,
    Icons.shield_outlined,
  ),
  subscription(
    'subscription',
    'Subscription',
    AppColors.catSubscription,
    Icons.subscriptions_outlined,
  ),
  idLicense(
    'id_license',
    'ID / License',
    AppColors.catDocument,
    Icons.badge_outlined,
  ),
  insurance(
    'insurance',
    'Insurance',
    AppColors.catInsurance,
    Icons.health_and_safety_outlined,
  ),
  medicine(
    'medicine',
    'Medicine',
    AppColors.catMedicine,
    Icons.medication_outlined,
  ),
  grocery(
    'grocery',
    'Grocery',
    AppColors.catGrocery,
    Icons.local_grocery_store_outlined,
  ),
  bill('bill', 'Bill', AppColors.catBill, Icons.receipt_long_outlined),
  document(
    'document',
    'Document',
    AppColors.catDocument,
    Icons.description_outlined,
  ),
  other('other', 'Other', AppColors.catOther, Icons.label_outline);

  const ItemCategory(this.dbValue, this.label, this.surface, this.icon);
  final String dbValue;
  final String label;
  final Color surface;
  final IconData icon;

  static ItemCategory fromDb(String value) => ItemCategory.values.firstWhere(
    (c) => c.dbValue == value,
    orElse: () => ItemCategory.other,
  );
}
