import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:stayon/core/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:stayon/core/database/cached_product_dao.dart';
import 'package:stayon/core/models/extraction_result.dart';

/// Exception thrown during barcode lookup operations.
class BarcodeException implements Exception {
  BarcodeException({required this.code, required this.message});

  /// Error code: 'not_found', 'rate_limited', 'server_error', 'network_error', 'invalid_barcode', 'parse_error'
  final String code;

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'BarcodeException($code): $message';
}

/// Internal model for Open Food Facts API response.
class _Product {
  _Product({
    required this.productName,
    this.brands,
    this.expirationDate,
    this.genericName,
  });

  /// Parse from Open Food Facts API response.
  factory _Product.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) {
      throw BarcodeException(
        code: 'parse_error',
        message: 'No product object in response',
      );
    }

    final productName = product['product_name'] as String?;
    if (productName == null || productName.isEmpty) {
      throw BarcodeException(
        code: 'parse_error',
        message: 'Missing product_name in response',
      );
    }

    return _Product(
      productName: productName,
      brands: product['brands'] as String?,
      expirationDate: product['expiration_date'] as String?,
      genericName: product['generic_name'] as String?,
    );
  }

  final String productName;
  final String? brands;
  final String? expirationDate;
  final String? genericName;

  /// Convert to ExtractionResult data map.
  Map<String, dynamic> toExtractionData() => {
    'product_name': productName,
    if (brands != null) 'brands': brands,
    if (expirationDate != null) 'expiration_date': expirationDate,
    if (genericName != null) 'generic_name': genericName,
  };
}

/// HTTP client for Open Food Facts API with caching and retry logic.
///
/// Features:
/// - Cache-first strategy: checks Drift before making API calls
/// - Exponential backoff retry: 1s, 2s, 4s on 5xx/timeout
/// - Confidence scoring: 0.95 (API), 0.90 (cache), 0.0 (not found)
/// - Explicit error handling: BarcodeException for all failures
class OpenFoodFactsService {
  OpenFoodFactsService({
    required CachedProductDao cachedProductDao,
    http.Client? httpClient,
  }) : _cachedProductDao = cachedProductDao,
       _httpClient = httpClient ?? http.Client();

  static const _baseUrl = 'https://world.openfoodfacts.org/api/v3/product';
  static const _maxRetries = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];

  final CachedProductDao _cachedProductDao;
  final http.Client _httpClient;

  /// Lookup a product by barcode.
  ///
  /// Returns [ExtractionResult] with:
  /// - type: 'barcode'
  /// - data: {product_name, brands?, expiration_date?, generic_name?}
  /// - confidence: 0.95 (API), 0.90 (cache), 0.0 (not found), 0.5 (parse error)
  /// - warnings: List of non-fatal issues
  ///
  /// Throws [BarcodeException] on network errors or server failures.
  Future<ExtractionResult> lookupBarcode(String barcode) async {
    if (barcode.isEmpty) {
      throw BarcodeException(
        code: 'invalid_barcode',
        message: 'Barcode cannot be empty',
      );
    }

    // Validate barcode format (alphanumeric, 8-18 digits).
    if (!RegExp(r'^\d{8,18}$').hasMatch(barcode)) {
      throw BarcodeException(
        code: 'invalid_barcode',
        message: 'Barcode must be 8-18 digits',
      );
    }

    // Check cache first (respects 7-day TTL by default).
    final cachedProduct = await _cachedProductDao.getCachedProduct(barcode);
    if (cachedProduct != null) {
      try {
        final data =
            jsonDecode(cachedProduct.productData) as Map<String, dynamic>;
        return ExtractionResult(
          type: 'barcode',
          data: data,
          confidence: 0.90,
          warnings: ['Data from local cache; may be stale'],
        );
      } catch (e) {
        // Cache corruption; fall through to API call.
      }
    }

    // Cache miss: call API with retry logic.
    final product = await _retryable(() => _fetchFromApi(barcode));

    // Save to cache.
    await _cachedProductDao.insertCachedProduct(
      CachedProductsCompanion(
        id: Value('$barcode-${DateTime.now().millisecondsSinceEpoch}'),
        barcode: Value(barcode),
        productData: Value(jsonEncode(product.toExtractionData())),
        createdAt: Value(DateTime.now()),
      ),
    );

    return ExtractionResult(
      type: 'barcode',
      data: product.toExtractionData(),
      confidence: 0.95,
      warnings: const [],
    );
  }

  /// Fetch product from Open Food Facts API.
  ///
  /// Throws [BarcodeException] on 404, 429, 5xx, network errors, or parse errors.
  Future<_Product> _fetchFromApi(String barcode) async {
    final uri = Uri.parse('$_baseUrl/$barcode.json');

    try {
      final response = await _httpClient
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw BarcodeException(
                code: 'network_error',
                message: 'Request timeout after 10 seconds',
              );
            },
          );

      // Handle 404: not found.
      if (response.statusCode == 404) {
        throw BarcodeException(
          code: 'not_found',
          message: 'Product not found in Open Food Facts database',
        );
      }

      // Handle 429: rate limit (do NOT retry).
      if (response.statusCode == 429) {
        throw BarcodeException(
          code: 'rate_limited',
          message: 'Rate limit exceeded; try again later',
        );
      }

      // Handle 5xx: server error (will be retried by _retryable).
      if (response.statusCode >= 500) {
        throw BarcodeException(
          code: 'server_error',
          message: 'Open Food Facts server error (${response.statusCode})',
        );
      }

      // Handle other 4xx: bad request.
      if (response.statusCode >= 400) {
        throw BarcodeException(
          code: 'invalid_barcode',
          message: 'Invalid barcode format (${response.statusCode})',
        );
      }

      // Parse successful response.
      if (response.statusCode != 200) {
        throw BarcodeException(
          code: 'server_error',
          message: 'Unexpected HTTP status ${response.statusCode}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _Product.fromJson(json);
    } on BarcodeException {
      rethrow;
    } catch (e) {
      throw BarcodeException(
        code: 'network_error',
        message: 'Network error: $e',
      );
    }
  }

  /// Retry logic with exponential backoff.
  ///
  /// Retries on:
  /// - 5xx server errors
  /// - Network timeouts
  ///
  /// Does NOT retry on:
  /// - 404, 400, 429 (non-retriable errors)
  /// - Parse errors
  Future<T> _retryable<T>(Future<T> Function() fn) async {
    BarcodeException? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await fn();
      } on BarcodeException catch (e) {
        // Only retry on server errors and timeouts.
        if (e.code == 'server_error' || e.code == 'network_error') {
          lastError = e;
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(_retryDelays[attempt]);
          }
        } else {
          // Non-retriable error: throw immediately.
          rethrow;
        }
      }
    }

    // All retries exhausted.
    throw lastError ??
        BarcodeException(
          code: 'server_error',
          message: 'All retry attempts exhausted',
        );
  }
}
