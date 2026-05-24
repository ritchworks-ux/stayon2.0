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

  /// Retrieve a cached product by barcode.
  Future<CachedProduct?> getCachedProduct(String barcode) async {
    return (select(
      cachedProducts,
    )..where((tbl) => tbl.barcode.equals(barcode))).getSingleOrNull();
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
}
