import 'package:drift/drift.dart';
import 'app_database.dart';

part 'cached_product_dao.g.dart';

@DriftAccessor(tables: [CachedProducts])
class CachedProductDao extends DatabaseAccessor<AppDatabase>
    with _$CachedProductDaoMixin {
  CachedProductDao(super.db);

  /// Insert or replace a cached product result.
  Future<void> insertCachedProduct(CachedProductsCompanion product) async {
    await into(cachedProducts).insertOnConflictUpdate(product);
  }

  /// Retrieve a cached product by barcode if not expired.
  ///
  /// Returns null if the cached product is older than [maxAgeDays].
  /// Default maxAgeDays is 7 days.
  Future<CachedProduct?> getCachedProduct(
    String barcode, {
    int maxAgeDays = 7,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));
    final query = select(cachedProducts)
      ..where(
        (tbl) =>
            tbl.barcode.equals(barcode) &
            tbl.createdAt.isBiggerThanValue(cutoffDate),
      );
    return query.getSingleOrNull();
  }

  /// Delete a cached product by barcode.
  Future<int> deleteCachedProduct(String barcode) async {
    return (delete(
      cachedProducts,
    )..where((tbl) => tbl.barcode.equals(barcode))).go();
  }

  /// Clear all cached products.
  Future<int> clearCache() async {
    return delete(cachedProducts).go();
  }

  /// Count cached products.
  Future<int> countCachedProducts() async {
    final query = selectOnly(cachedProducts)..addColumns([countAll()]);
    final result = await query.map((row) => row.read(countAll())).getSingle();
    return result ?? 0;
  }

  /// Get all cached products.
  Future<List<CachedProduct>> getAllCachedProducts() async {
    return select(cachedProducts).get();
  }

  /// Delete cached products older than [maxAgeDays].
  ///
  /// This prevents database bloat from accumulated stale entries.
  /// Default maxAgeDays is 30 days.
  Future<int> cleanupStaleProducts({int maxAgeDays = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: maxAgeDays));
    return (delete(
      cachedProducts,
    )..where((tbl) => tbl.createdAt.isSmallerThanValue(cutoffDate))).go();
  }
}
