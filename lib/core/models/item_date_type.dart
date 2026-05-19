/// What a target_date means for a given item. Stored as `dbValue` strings
/// in Postgres (see migration 0002_items.sql CHECK constraint).
enum ItemDateType {
  expires('expires', 'Expires'),
  renews('renews', 'Renews'),
  due('due', 'Due');

  const ItemDateType(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static ItemDateType fromDb(String value) =>
      ItemDateType.values.firstWhere((e) => e.dbValue == value);
}
