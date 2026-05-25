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

    test(
      'getCachedProduct respects TTL: returns product within 7-day default window',
      () async {
        final sixDaysAgo = DateTime.now().subtract(const Duration(days: 6));
        final companion = CachedProductsCompanion(
          id: const Value('prod-ttl-1'),
          barcode: const Value('999999999999'),
          productData: const Value('{"product_name":"TTL Product"}'),
          createdAt: Value(sixDaysAgo),
        );

        await db.cachedProductDao.insertCachedProduct(companion);

        // Should be found within default 7-day TTL
        final result = await db.cachedProductDao.getCachedProduct(
          '999999999999',
        );
        expect(result, isNotNull);
        expect(result!.barcode, '999999999999');
      },
    );

    test(
      'getCachedProduct respects TTL: returns null for product older than 7 days',
      () async {
        final eightDaysAgo = DateTime.now().subtract(const Duration(days: 8));
        final companion = CachedProductsCompanion(
          id: const Value('prod-ttl-2'),
          barcode: const Value('888888888888'),
          productData: const Value('{"product_name":"Stale Product"}'),
          createdAt: Value(eightDaysAgo),
        );

        await db.cachedProductDao.insertCachedProduct(companion);

        // Should NOT be found (older than 7-day TTL)
        final result = await db.cachedProductDao.getCachedProduct(
          '888888888888',
        );
        expect(result, isNull);
      },
    );

    test('getCachedProduct respects custom maxAgeDays parameter', () async {
      final fifteenDaysAgo = DateTime.now().subtract(const Duration(days: 15));
      final companion = CachedProductsCompanion(
        id: const Value('prod-ttl-3'),
        barcode: const Value('777777777777'),
        productData: const Value('{"product_name":"Old Product"}'),
        createdAt: Value(fifteenDaysAgo),
      );

      await db.cachedProductDao.insertCachedProduct(companion);

      // With default 7-day TTL, should be null
      var result = await db.cachedProductDao.getCachedProduct('777777777777');
      expect(result, isNull);

      // With 30-day custom TTL, should be found
      result = await db.cachedProductDao.getCachedProduct(
        '777777777777',
        maxAgeDays: 30,
      );
      expect(result, isNotNull);
      expect(result!.barcode, '777777777777');
    });

    test(
      'cleanupStaleProducts removes products older than 30 days (default)',
      () async {
        final thirtyFiveDaysAgo = DateTime.now().subtract(
          const Duration(days: 35),
        );
        final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
        final recentNow = DateTime.now();

        await db.cachedProductDao.insertCachedProduct(
          CachedProductsCompanion(
            id: const Value('old-1'),
            barcode: const Value('1111111111111'),
            productData: const Value('{"name":"Old"}'),
            createdAt: Value(thirtyFiveDaysAgo),
          ),
        );

        await db.cachedProductDao.insertCachedProduct(
          CachedProductsCompanion(
            id: const Value('recent-1'),
            barcode: const Value('2222222222222'),
            productData: const Value('{"name":"Recent"}'),
            createdAt: Value(twoDaysAgo),
          ),
        );

        await db.cachedProductDao.insertCachedProduct(
          CachedProductsCompanion(
            id: const Value('new-1'),
            barcode: const Value('3333333333333'),
            productData: const Value('{"name":"New"}'),
            createdAt: Value(recentNow),
          ),
        );

        var countBefore = await db.cachedProductDao.countCachedProducts();
        expect(countBefore, 3);

        // Run cleanup with default 30-day threshold
        final deletedCount = await db.cachedProductDao.cleanupStaleProducts();
        expect(deletedCount, 1);

        var countAfter = await db.cachedProductDao.countCachedProducts();
        expect(countAfter, 2);
      },
    );

    test('cleanupStaleProducts respects custom maxAgeDays parameter', () async {
      final tenDaysAgo = DateTime.now().subtract(const Duration(days: 10));
      final recentNow = DateTime.now();

      await db.cachedProductDao.insertCachedProduct(
        CachedProductsCompanion(
          id: const Value('mid-1'),
          barcode: const Value('4444444444444'),
          productData: const Value('{"name":"Mid"}'),
          createdAt: Value(tenDaysAgo),
        ),
      );

      await db.cachedProductDao.insertCachedProduct(
        CachedProductsCompanion(
          id: const Value('new-2'),
          barcode: const Value('5555555555555'),
          productData: const Value('{"name":"New"}'),
          createdAt: Value(recentNow),
        ),
      );

      // Run cleanup with custom 5-day threshold
      final deletedCount = await db.cachedProductDao.cleanupStaleProducts(
        maxAgeDays: 5,
      );
      expect(deletedCount, 1);

      var countAfter = await db.cachedProductDao.countCachedProducts();
      expect(countAfter, 1);
    });

    test('cleanupStaleProducts does not delete recent products', () async {
      final now = DateTime.now();
      await db.cachedProductDao.insertCachedProduct(
        CachedProductsCompanion(
          id: const Value('now-1'),
          barcode: const Value('6666666666666'),
          productData: const Value('{"name":"Now"}'),
          createdAt: Value(now),
        ),
      );

      final deletedCount = await db.cachedProductDao.cleanupStaleProducts();
      expect(deletedCount, 0);

      var count = await db.cachedProductDao.countCachedProducts();
      expect(count, 1);
    });
  });
}
