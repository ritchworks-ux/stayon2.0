# Barcode Service Integration Guide

For teams building T3 (Mobile Scanner wrapper) and downstream features.

---

## Quick Start

### Import the Service

```dart
import 'package:stayon/features/attachments/services/open_food_facts_service.dart';
import 'package:stayon/core/database/app_database.dart';
```

### Initialize (T3 onwards)

```dart
// In your provider or dependency setup
final barcodeServiceProvider = Provider<OpenFoodFactsService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OpenFoodFactsService(
    cachedProductDao: db.cachedProductDao,
    // httpClient: null,  // Omit to use real http.Client()
  );
});
```

### Use in Your Code (T3 onwards)

```dart
class BarcodeService {
  const BarcodeService(this._offService);

  final OpenFoodFactsService _offService;

  Future<ExtractionResult> scanAndLookup(String rawBarcode) async {
    try {
      return await _offService.lookupBarcode(rawBarcode);
    } on BarcodeException catch (e) {
      // Log error, show user message, etc.
      rethrow;
    }
  }
}
```

---

## Return Type: ExtractionResult

```dart
@freezed
class ExtractionResult with _$ExtractionResult {
  const factory ExtractionResult({
    required String type,                    // 'barcode'
    required Map<String, dynamic> data,      // {product_name, brands?, ...}
    required double confidence,              // 0.95, 0.90, 0.5, or 0.0
    @Default([]) List<String> warnings,      // ['Data from cache; may be stale']
  }) = _ExtractionResult;

  factory ExtractionResult.fromJson(Map<String, dynamic> json) =>
      _$ExtractionResultFromJson(json);
}
```

### Accessing Data

```dart
final result = await service.lookupBarcode(barcode);

// Required fields
final productName = result.data['product_name'] as String;

// Optional fields (null-check required)
final brands = result.data['brands'] as String?;
final expirationDate = result.data['expiration_date'] as String?;
final genericName = result.data['generic_name'] as String?;

// Confidence & warnings
print('Confidence: ${result.confidence * 100}%');  // 95%, 90%, 50%, 0%
if (result.warnings.isNotEmpty) {
  print('Warnings: ${result.warnings}');
}
```

---

## Error Handling

### Exception Type

```dart
class BarcodeException implements Exception {
  final String code;      // error category
  final String message;   // user-friendly message
}
```

### Error Codes & Responses

| Code | HTTP Status | Retry? | User Message |
|------|-------------|--------|--------------|
| `not_found` | 404 | ✗ | "Product not found. Try another barcode." |
| `rate_limited` | 429 | ✗ | "Service busy. Try again in a moment." |
| `server_error` | 5xx | ✓ | "Server error. Check connection." |
| `network_error` | Timeout | ✓ | "Network error. Check internet." |
| `invalid_barcode` | 4xx other | ✗ | "Invalid barcode format." |
| `parse_error` | 200 (malformed) | ✗ | "Could not parse product. Try another." |

### Example Error Handling

```dart
try {
  final result = await service.lookupBarcode(barcode);
  
  // Show product in UI
  showProductCard(
    name: result.data['product_name'],
    confidence: result.confidence,
    warnings: result.warnings,
  );
} on BarcodeException catch (e) {
  // Handle by error code
  final message = _errorMessage(e.code);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String _errorMessage(String code) => switch (code) {
  'not_found' => 'Product not found. Try another barcode.',
  'rate_limited' => 'Service busy. Try again in a moment.',
  'server_error' => 'Server error. Check your connection.',
  'network_error' => 'Network error. Check internet connection.',
  'invalid_barcode' => 'Invalid barcode format.',
  'parse_error' => 'Could not parse product. Try another.',
  _ => 'Unknown error.',
};
```

---

## Confidence Scoring in UI

### Show Confidence to User

```dart
// Method 1: Stars
Widget _confidenceStars(double confidence) {
  final stars = (confidence * 5).round();
  return Row(
    children: List.generate(5, (i) {
      return Icon(
        i < stars ? Icons.star : Icons.star_border,
        color: Colors.amber,
      );
    }),
  );
}

// Method 2: Badge
Widget _confidenceBadge(double confidence) {
  final percent = (confidence * 100).toInt();
  return Chip(
    label: Text('$percent% confident'),
    backgroundColor: confidence >= 0.95
        ? Colors.green
        : confidence >= 0.90
            ? Colors.blue
            : Colors.orange,
  );
}

// Method 3: Inline text
final confidenceText = confidence >= 0.95
    ? 'High confidence'
    : confidence >= 0.90
        ? 'From cache (may be stale)'
        : 'Low confidence';
```

### Warn on Cache Staleness

```dart
if (result.warnings.contains('Data from local cache; may be stale')) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Data from Cache'),
      content: const Text('This product info may be outdated. '
          'Refresh your internet connection for latest data.'),
      actions: [
        TextButton(onPressed: Navigator.of(context).pop, child: const Text('OK')),
      ],
    ),
  );
}
```

---

## Testing Your Integration

### Mock the Service in Your Tests

```dart
class _MockBarcodeService extends Mock implements OpenFoodFactsService {}

void main() {
  late _MockBarcodeService mockService;

  setUp(() {
    mockService = _MockBarcodeService();
  });

  test('shows product on successful barcode scan', () async {
    const result = ExtractionResult(
      type: 'barcode',
      data: {
        'product_name': 'Lactose-free milk',
        'brands': 'Arla Foods',
      },
      confidence: 0.95,
      warnings: [],
    );

    when(() => mockService.lookupBarcode(any()))
        .thenAnswer((_) async => result);

    // Test your UI code here...
  });

  test('shows error message on not_found', () async {
    when(() => mockService.lookupBarcode(any()))
        .thenThrow(BarcodeException(
          code: 'not_found',
          message: 'Product not found',
        ));

    // Test error handling...
  });
}
```

---

## Caching Behavior

### First Call (Cache Miss)

```dart
await service.lookupBarcode('5901012016015');
// → Makes HTTP GET request
// → Saves to Drift DB
// → Returns confidence 0.95
```

### Second Call (Cache Hit)

```dart
await service.lookupBarcode('5901012016015');
// → Reads from Drift DB (instant, no HTTP)
// → Returns confidence 0.90
// → Includes warning: "Data from local cache; may be stale"
```

### Cache Invalidation

Currently, the cache is **session-based** (cleared on app restart). Future work (T4+) will add TTL policies.

```dart
// If needed, clear cache manually (future feature):
// await dao.clearCache();
```

---

## Performance Notes

### Typical Lookup Time

| Scenario | Time | Notes |
|----------|------|-------|
| Cache hit | <10ms | Instant Drift lookup |
| API success | 200–500ms | Network + parsing |
| API retry (1x) | 1000–1500ms | 1s delay + API call |
| Timeout (10s) | 10000ms | Then thrown as error |

### Network Considerations

- **Offline**: Network errors thrown; user should see message
- **Slow network**: 10-second timeout may trigger; consider longer timeout if needed
- **Rate limit**: 429 thrown immediately; queue retry in UI

---

## Data Model Reference

### Open Food Facts Response → ExtractionResult

```json
{
  "product": {
    "product_name": "Lactose-free milk",
    "brands": "Arla Foods",
    "expiration_date": "2026-06-24",
    "generic_name": "Milk"
  }
}
```

**Becomes**:

```dart
ExtractionResult(
  type: 'barcode',
  data: {
    'product_name': 'Lactose-free milk',
    'brands': 'Arla Foods',
    'expiration_date': '2026-06-24',
    'generic_name': 'Milk',
  },
  confidence: 0.95,
  warnings: [],
)
```

### Storing in Attachment

```dart
final extraction = await service.lookupBarcode(barcode);

final attachment = Attachment(
  id: generateId(),
  ownerId: userId,
  itemId: itemId,
  filename: 'barcode-$barcode',
  contentType: 'application/json',
  fileSizeBytes: 0,
  storagePath: 'inline',
  storageTier: 'memory',
  extractionType: extraction.type,           // 'barcode'
  extractionData: extraction.data,           // {product_name, ...}
  extractionConfidence: extraction.confidence, // 0.95
  extractionReviewedAt: null,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// Save to Supabase...
```

---

## Common Pitfalls & Solutions

### Pitfall 1: Not Handling Optional Fields

```dart
// ❌ WRONG: Will crash if 'brands' is null
final brands = result.data['brands'] as String;

// ✅ CORRECT: Null-safe
final brands = result.data['brands'] as String?;
if (brands != null) {
  print('Brand: $brands');
}
```

### Pitfall 2: Ignoring Confidence

```dart
// ❌ WRONG: Treats cache (0.90) same as API (0.95)
showProduct(result.data);

// ✅ CORRECT: Show confidence to user
showProduct(
  result.data,
  confidence: result.confidence,
  isCached: result.confidence < 0.95,
);
```

### Pitfall 3: Retrying 404 or 429 in UI

```dart
// ❌ WRONG: Will keep failing
try {
  result = await service.lookupBarcode(barcode);
} on BarcodeException catch (e) {
  if (e.code == 'not_found') {
    // Retrying won't help!
    result = await service.lookupBarcode(barcode);  // No!
  }
}

// ✅ CORRECT: Show message instead
} on BarcodeException catch (e) {
  if (e.code == 'not_found') {
    showSnackBar('Product not found. Try another barcode.');
  }
}
```

### Pitfall 4: Assuming Instant Caching

```dart
// ❌ WRONG: Cache save is async
await service.lookupBarcode(barcode);
// Cache might not be saved yet!

// ✅ CORRECT: Cache saved before return
final result = await service.lookupBarcode(barcode);
// Cache guaranteed saved at this point
```

---

## FAQ

### Q: Can I use a custom HTTP client?

**A**: Yes! Inject in the constructor:

```dart
final service = OpenFoodFactsService(
  cachedProductDao: db.cachedProductDao,
  httpClient: customHttpClient,  // Your client
);
```

### Q: How do I clear the cache?

**A**: Directly via DAO (future UI feature):

```dart
await db.cachedProductDao.clearCache();
```

### Q: Why is confidence 0.90 for cache?

**A**: To signal to UI that data might be stale (product info changes). At 0.95, we commit to "current"; at 0.90, we admit "might be outdated".

### Q: Does it retry on 429?

**A**: No. Rate limits mean you're asking too much of the API. Retrying immediately violates rate limit policy. Queue for later (future work).

### Q: What if the API is down?

**A**: Throws `BarcodeException(code: 'server_error', ...)` after 3 retries (1s, 2s, 4s backoff). Cache saves you here if the barcode was looked up before.

### Q: Is the cache persistent across app restarts?

**A**: Yes! Drift stores in SQLite, which survives app restart. Session-based expiry (no TTL currently) means old data never auto-expires. Future work to add TTL.

---

## API Reference (Dart)

### Class: OpenFoodFactsService

```dart
class OpenFoodFactsService {
  OpenFoodFactsService({
    required CachedProductDao cachedProductDao,
    http.Client? httpClient,
  });

  /// Lookup a product by barcode.
  ///
  /// Returns [ExtractionResult] with product data and confidence score.
  /// Throws [BarcodeException] on non-retriable errors.
  Future<ExtractionResult> lookupBarcode(String barcode);
}
```

### Exception: BarcodeException

```dart
class BarcodeException implements Exception {
  BarcodeException({required this.code, required this.message});

  /// Error code: 'not_found', 'rate_limited', 'server_error', 
  /// 'network_error', 'invalid_barcode', 'parse_error'
  final String code;

  /// Human-readable message
  final String message;

  @override
  String toString() => 'BarcodeException($code): $message';
}
```

---

## File Paths

**Service**: `/lib/features/attachments/services/open_food_facts_service.dart`

**Tests**: `/test/features/attachments/services/open_food_facts_service_test.dart`

**API Spec**: `/docs/BARCODE_API_SPEC.md`

**This Guide**: `/BARCODE_INTEGRATION_GUIDE.md`

---

## Support & Questions

Refer to:
1. **BARCODE_API_SPEC.md** — Complete API specification
2. **T2_BARCODE_SERVICE_REPORT.md** — Implementation details
3. **open_food_facts_service.dart** — Inline documentation & source
4. **open_food_facts_service_test.dart** — 14 test examples

All tests passing. Service ready for integration.
