/// Lifecycle status of an item. Stored as `dbValue` strings in Postgres
/// (see migration 0002_items.sql CHECK constraint).
///
/// - [active] — visible on Home dashboard
/// - [archived] — hidden from Home; restorable (no Phase 2 UI yet)
/// - [trashed] — hidden everywhere; restorable via Phase 2 undo snackbar
///   or future Trash screen; purged after 30 days by the Phase 6 cron job
enum ItemStatus {
  active('active'),
  archived('archived'),
  trashed('trashed');

  const ItemStatus(this.dbValue);
  final String dbValue;

  static ItemStatus fromDb(String value) =>
      ItemStatus.values.firstWhere((e) => e.dbValue == value);
}
