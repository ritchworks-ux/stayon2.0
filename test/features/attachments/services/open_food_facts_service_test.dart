import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'package:stayon/core/database/cached_product_dao.dart';
import 'package:stayon/features/attachments/services/open_food_facts_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _MockCachedProductDao extends Mock implements CachedProductDao {}

void main() {
  late _MockHttpClient mockHttpClient;
  late _MockCachedProductDao mockCachedProductDao;
  late OpenFoodFactsService service;

  setUp(() {
    mockHttpClient = _MockHttpClient();
    mockCachedProductDao = _MockCachedProductDao();
    service = OpenFoodFactsService(
      cachedProductDao: mockCachedProductDao,
      httpClient: mockHttpClient,
    );
  });

  group('OpenFoodFactsService', () {
    group('lookupBarcode', () {
      const testBarcode = '5901012016015';

      const successResponse = '''{
        "product": {
          "product_name": "Lactose-free milk",
          "brands": "Arla Foods",
          "expiration_date": "2026-06-24",
          "generic_name": "Milk"
        }
      }''';

      test('Test 1: Successful barcode lookup (HTTP 200)', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        when(
          () => mockHttpClient.get(
            any(),
          ),
        ).thenAnswer(
          (_) async => http.Response(successResponse, 200),
        );

        when(
          () => mockCachedProductDao.insertCachedProduct(any()),
        ).thenAnswer((_) async => Future.value());

        final result = await service.lookupBarcode(testBarcode);

        expect(result.type, 'barcode');
        expect(result.data['product_name'], 'Lactose-free milk');
        expect(result.data['brands'], 'Arla Foods');
        expect(result.data['expiration_date'], '2026-06-24');
        expect(result.data['generic_name'], 'Milk');
        expect(result.confidence, 0.95);
        expect(result.warnings, isEmpty);

        verify(() => mockCachedProductDao.insertCachedProduct(any()))
            .called(1);
      });

      test('Test 2: Barcode not found (HTTP 404) returns 0.0 confidence',
          () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async => http.Response('', 404));

        expect(
          () => service.lookupBarcode(testBarcode),
          throwsA(
            isA<BarcodeException>()
                .having((e) => e.code, 'code', 'not_found')
                .having((e) => e.message, 'message',
                    'Product not found in Open Food Facts database'),
          ),
        );
      });

      test('Test 3: Rate limit (HTTP 429) does NOT retry', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async => http.Response('', 429));

        expect(
          () => service.lookupBarcode(testBarcode),
          throwsA(
            isA<BarcodeException>()
                .having((e) => e.code, 'code', 'rate_limited'),
          ),
        );

        // Should only call once, no retries.
        verify(() => mockHttpClient.get(any())).called(1);
      });

      test('Test 4: Server error (HTTP 500) retries with exponential backoff',
          () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        // First two attempts fail with 500, third succeeds.
        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => http.Response('', 500),
        ).thenAnswer(
          (_) async => http.Response('', 500),
        ).thenAnswer(
          (_) async => http.Response(successResponse, 200),
        );

        when(
          () => mockCachedProductDao.insertCachedProduct(any()),
        ).thenAnswer((_) async => Future.value());

        final result = await service.lookupBarcode(testBarcode);

        expect(result.confidence, 0.95);
        expect(result.data['product_name'], 'Lactose-free milk');

        // Should call 3 times (1 initial + 2 retries).
        verify(() => mockHttpClient.get(any())).called(3);
      });

      test('Test 5: Cache hit returns data without HTTP call', () async {
        final cachedProduct = _FakeCachedProduct(
          barcode: testBarcode,
          productData:
              '{"product_name":"Cached Milk","brands":"Cached Brand"}',
        );

        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => cachedProduct);

        final result = await service.lookupBarcode(testBarcode);

        expect(result.type, 'barcode');
        expect(result.data['product_name'], 'Cached Milk');
        expect(result.data['brands'], 'Cached Brand');
        expect(result.confidence, 0.90);
        expect(result.warnings, contains('Data from local cache; may be stale'));

        // HTTP client should NOT be called.
        verifyNever(() => mockHttpClient.get(any()));
      });

      test('Test 6: Cache miss calls API and saves to cache', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async => http.Response(successResponse, 200));

        when(
          () => mockCachedProductDao.insertCachedProduct(any()),
        ).thenAnswer((_) async => Future.value());

        final result = await service.lookupBarcode(testBarcode);

        expect(result.confidence, 0.95);
        expect(result.data['product_name'], 'Lactose-free milk');

        // Should cache the result.
        verify(() => mockCachedProductDao.insertCachedProduct(any()))
            .called(1);
      });

      test('Test 7: Network timeout throws BarcodeException', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(minutes: 5));
          return http.Response('', 200);
        });

        expect(
          () => service.lookupBarcode(testBarcode),
          throwsA(
            isA<BarcodeException>()
                .having((e) => e.code, 'code', 'network_error'),
          ),
        );
      });

      test('Test 8: JSON parse error returns 0.5 confidence', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => http.Response('{"product": null}', 200),
        );

        expect(
          () => service.lookupBarcode(testBarcode),
          throwsA(
            isA<BarcodeException>()
                .having((e) => e.code, 'code', 'parse_error'),
          ),
        );
      });

      test('Test 9: Retry success (first fails, second succeeds)', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        // First attempt fails with 500, second succeeds.
        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => http.Response('', 500),
        ).thenAnswer(
          (_) async => http.Response(successResponse, 200),
        );

        when(
          () => mockCachedProductDao.insertCachedProduct(any()),
        ).thenAnswer((_) async => Future.value());

        final result = await service.lookupBarcode(testBarcode);

        expect(result.confidence, 0.95);
        expect(result.data['product_name'], 'Lactose-free milk');

        // Should call twice (1 initial + 1 retry).
        verify(() => mockHttpClient.get(any())).called(2);
      });

      test('Test 10: Empty barcode throws invalid_barcode', () async {
        expect(
          () => service.lookupBarcode(''),
          throwsA(
            isA<BarcodeException>()
                .having((e) => e.code, 'code', 'invalid_barcode'),
          ),
        );

        // Should not call any external service.
        verifyNever(() => mockHttpClient.get(any()));
        verifyNever(() => mockCachedProductDao.getCachedProduct(any()));
      });

      test('Test 11: Missing product_name in response throws parse_error',
          () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        const missingNameResponse = '''{
          "product": {
            "brands": "Arla Foods"
          }
        }''';

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer(
          (_) async => http.Response(missingNameResponse, 200),
        );

        expect(
          () => service.lookupBarcode(testBarcode),
          throwsA(
            isA<BarcodeException>()
                .having((e) => e.code, 'code', 'parse_error'),
          ),
        );
      });

      test('Test 12: Cache corruption falls through to API call', () async {
        final corruptedProduct = _FakeCachedProduct(
          barcode: testBarcode,
          productData: 'invalid json {',
        );

        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => corruptedProduct);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async => http.Response(successResponse, 200));

        when(
          () => mockCachedProductDao.insertCachedProduct(any()),
        ).thenAnswer((_) async => Future.value());

        final result = await service.lookupBarcode(testBarcode);

        expect(result.confidence, 0.95);
        expect(result.data['product_name'], 'Lactose-free milk');

        // Should have called the API (cache corruption recovery).
        verify(() => mockHttpClient.get(any())).called(1);
      });

      test('Test 13: All retries exhausted throws server_error', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async => http.Response('', 500));

        expect(
          () => service.lookupBarcode(testBarcode),
          throwsA(
            isA<BarcodeException>()
                .having((e) => e.code, 'code', 'server_error'),
          ),
        );

        // Should call 3 times (all retries).
        verify(() => mockHttpClient.get(any())).called(3);
      });

      test('Test 14: Minimal response (only product_name) succeeds', () async {
        when(
          () => mockCachedProductDao.getCachedProduct(testBarcode),
        ).thenAnswer((_) async => null);

        const minimalResponse = '''{
          "product": {
            "product_name": "Simple Product"
          }
        }''';

        when(
          () => mockHttpClient.get(any()),
        ).thenAnswer((_) async => http.Response(minimalResponse, 200));

        when(
          () => mockCachedProductDao.insertCachedProduct(any()),
        ).thenAnswer((_) async => Future.value());

        final result = await service.lookupBarcode(testBarcode);

        expect(result.type, 'barcode');
        expect(result.data['product_name'], 'Simple Product');
        expect(result.data.containsKey('brands'), isFalse);
        expect(result.data.containsKey('expiration_date'), isFalse);
        expect(result.confidence, 0.95);
      });
    });
  });
}

/// Fake CachedProduct for testing.
class _FakeCachedProduct implements Comparable {
  _FakeCachedProduct({
    required this.barcode,
    required this.productData,
    this.id = 'test-id',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String barcode;
  final String productData;
  final DateTime createdAt;

  @override
  int compareTo(other) => 0;
}
