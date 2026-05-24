import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/database/app_database.dart';

void main() {
  group('CachedProductDao', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('insertCachedProduct and getCachedProduct', () async {
      final companion = CachedProductsCompanion(
        id: const Value('prod-1'),
        barcode: const Value('123456789012'),
        productData: const Value(
          '{"product_name":"Coca-Cola","brand":"Coca-Cola"}',
        ),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.cachedProductDao.insertCachedProduct(companion);
      final retrieved = await db.cachedProductDao.getCachedProduct(
        '123456789012',
      );

      expect(retrieved, isNotNull);
      expect(retrieved!.barcode, '123456789012');
      expect(retrieved.productData, contains('Coca-Cola'));
    });

    test('getCachedProduct returns null for non-existent barcode', () async {
      final result = await db.cachedProductDao.getCachedProduct(
        'nonexistent-barcode',
      );
      expect(result, isNull);
    });

    test('deleteCachedProduct removes product by barcode', () async {
      final companion = CachedProductsCompanion(
        id: const Value('prod-1'),
        barcode: const Value('123456789012'),
        productData: const Value('{"product_name":"Sprite"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.cachedProductDao.insertCachedProduct(companion);
      var retrieved = await db.cachedProductDao.getCachedProduct(
        '123456789012',
      );
      expect(retrieved, isNotNull);

      await db.cachedProductDao.deleteCachedProduct('123456789012');
      retrieved = await db.cachedProductDao.getCachedProduct('123456789012');
      expect(retrieved, isNull);
    });

    test('clearCache removes all products', () async {
      final prod1 = CachedProductsCompanion(
        id: const Value('prod-1'),
        barcode: const Value('111111111111'),
        productData: const Value('{"name":"Product 1"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      final prod2 = CachedProductsCompanion(
        id: const Value('prod-2'),
        barcode: const Value('222222222222'),
        productData: const Value('{"name":"Product 2"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.cachedProductDao.insertCachedProduct(prod1);
      await db.cachedProductDao.insertCachedProduct(prod2);

      var count = await db.cachedProductDao.countCachedProducts();
      expect(count, 2);

      await db.cachedProductDao.clearCache();
      count = await db.cachedProductDao.countCachedProducts();
      expect(count, 0);
    });

    test('countCachedProducts returns accurate count', () async {
      expect(await db.cachedProductDao.countCachedProducts(), 0);

      final prod1 = CachedProductsCompanion(
        id: const Value('prod-1'),
        barcode: const Value('111111111111'),
        productData: const Value('{"name":"Product 1"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      final prod2 = CachedProductsCompanion(
        id: const Value('prod-2'),
        barcode: const Value('222222222222'),
        productData: const Value('{"name":"Product 2"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.cachedProductDao.insertCachedProduct(prod1);
      expect(await db.cachedProductDao.countCachedProducts(), 1);

      await db.cachedProductDao.insertCachedProduct(prod2);
      expect(await db.cachedProductDao.countCachedProducts(), 2);
    });

    test('getAllCachedProducts returns all products', () async {
      final prod1 = CachedProductsCompanion(
        id: const Value('prod-1'),
        barcode: const Value('111111111111'),
        productData: const Value('{"name":"Product 1"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      final prod2 = CachedProductsCompanion(
        id: const Value('prod-2'),
        barcode: const Value('222222222222'),
        productData: const Value('{"name":"Product 2"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.cachedProductDao.insertCachedProduct(prod1);
      await db.cachedProductDao.insertCachedProduct(prod2);

      final all = await db.cachedProductDao.getAllCachedProducts();
      expect(all.length, 2);
      expect(
        all.map((p) => p.barcode).toList(),
        containsAll(['111111111111', '222222222222']),
      );
    });

    test('insertOnConflictUpdate replaces existing product', () async {
      final prod1 = CachedProductsCompanion(
        id: const Value('prod-1'),
        barcode: const Value('123456789012'),
        productData: const Value('{"name":"Old Name"}'),
        createdAt: Value(DateTime.utc(2026, 5, 24)),
      );

      await db.cachedProductDao.insertCachedProduct(prod1);
      var retrieved = await db.cachedProductDao.getCachedProduct(
        '123456789012',
      );
      expect(retrieved!.productData, contains('Old Name'));

      final prod2 = CachedProductsCompanion(
        id: const Value('prod-1'),
        barcode: const Value('123456789012'),
        productData: const Value('{"name":"New Name"}'),
        createdAt: Value(DateTime.utc(2026, 5, 25)),
      );

      await db.cachedProductDao.insertCachedProduct(prod2);
      retrieved = await db.cachedProductDao.getCachedProduct('123456789012');
      expect(retrieved!.productData, contains('New Name'));
    });
  });
}
