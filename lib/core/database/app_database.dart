import 'package:drift/drift.dart';
import 'attachment_dao.dart';
import 'cached_product_dao.dart';

part 'app_database.g.dart';

/// Tables for local SQLite caching (mirrors Supabase data).
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text().named('owner_id')();
  TextColumn get itemId => text().named('item_id')();
  TextColumn get filename => text()();
  TextColumn get contentType => text().named('content_type')();
  IntColumn get fileSizeBytes => integer().named('file_size_bytes')();
  TextColumn get storagePath => text().named('storage_path')();
  TextColumn get storageTier => text().named('storage_tier')();
  TextColumn get extractionType => text().named('extraction_type').nullable()();
  TextColumn get extractionData =>
      text().named('extraction_data').nullable()(); // JSON blob
  RealColumn get extractionConfidence =>
      real().named('extraction_confidence').nullable()();
  DateTimeColumn get extractionReviewedAt =>
      dateTime().named('extraction_reviewed_at').nullable()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => ['UNIQUE(owner_id, filename, item_id)'];
}

class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get barcode => text().unique()();
  TextColumn get productData => text().named('product_data')(); // JSON blob
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Attachments, CachedProducts],
  daos: [AttachmentDao, CachedProductDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;
}
