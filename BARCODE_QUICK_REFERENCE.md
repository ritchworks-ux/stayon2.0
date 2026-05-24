# Barcode Service — Quick Reference Card

**One-page cheat sheet for T3 teams and downstream integrators.**

---

## Import & Setup

```dart
// Import
import 'package:stayon/features/attachments/services/open_food_facts_service.dart';

// Initialize (in provider)
final barcodeServiceProvider = Provider<OpenFoodFactsService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return OpenFoodFactsService(cachedProductDao: db.cachedProductDao);
});
```

---

## Basic Usage

```dart
try {
  final result = await service.lookupBarcode('5901012016015');
  
  // Access data
  print(result.data['product_name']);      // "Lactose-free milk"
  print(result.confidence);                // 0.95 (API) or 0.90 (cache)
  
  // Show in UI
  showProduct(result);
  
} on BarcodeException catch (e) {
  // Handle error
  showError(e.code, e.message);
}
```

---

## Error Codes Quick Map

| Code | Action | Example |
|------|--------|---------|
| `not_found` | Barcode not in DB | "Product not found. Try another." |
| `rate_limited` | Too many requests | "Service busy. Try later." |
| `server_error` | API down | "Server error. Check connection." |
| `network_error` | No internet | "Network error. Check internet." |
| `invalid_barcode` | Bad format | "Invalid barcode format." |
| `parse_error` | JSON error | "Could not parse. Try another." |

---

## Retry Strategy

| Attempt | Delay |
|---------|-------|
| 1 | Immediate |
| 2 | +1s |
| 3 | +2s |
| 4 (fail) | throw |

**Retries on**: 5xx, timeout  
**Does NOT retry**: 404, 429, 400, parse error

---

## Confidence Interpretation

| Value | Source | Meaning |
|-------|--------|---------|
| 0.95 | API | Fresh from API |
| 0.90 | Cache | Local cache (may be stale) |
| 0.5–0.0 | Error | Partial/no data; exception thrown |

---

## Return Type: ExtractionResult

```dart
ExtractionResult(
  type: 'barcode',                              // Always 'barcode'
  data: {                                       // Product fields
    'product_name': 'Lactose-free milk',        // Required
    'brands': 'Arla Foods',                     // Optional
    'expiration_date': '2026-06-24',            // Optional
    'generic_name': 'Milk',                     // Optional
  },
  confidence: 0.95,                             // 0.95, 0.90, or exception
  warnings: ['Data from local cache; may be stale'],  // Non-fatal issues
)
```

---

## Error Handling Template

```dart
try {
  final result = await service.lookupBarcode(barcode);
  // Success: result.data, result.confidence available
} on BarcodeException catch (e) {
  switch (e.code) {
    case 'not_found':
      showSnackBar('Product not found. Try another barcode.');
    case 'rate_limited':
      showSnackBar('Service busy. Try again soon.');
    case 'server_error' || 'network_error':
      showSnackBar('${e.message} Check your connection.');
    case 'invalid_barcode':
      showSnackBar('Invalid barcode format.');
    case 'parse_error':
      showSnackBar('Could not parse product. Try another.');
    default:
      showSnackBar('Unknown error: ${e.message}');
  }
}
```

---

## Accessing Optional Fields (Null-Safe)

```dart
final result = await service.lookupBarcode(barcode);

// ✅ Correct
final brands = result.data['brands'] as String?;
if (brands != null) { /* use brands */ }

// ✅ Also correct (Elvis operator)
final expiration = (result.data['expiration_date'] as String?) ?? 'N/A';

// ❌ WRONG: Will crash if field is null
final brands = result.data['brands'] as String;  // No!
```

---

## Caching Behavior

| Call | Cache Status | Confidence | HTTP Call |
|------|--------------|-----------|-----------|
| 1st | Miss | 0.95 | ✓ Yes |
| 2nd (same barcode) | Hit | 0.90 | ✗ No |

---

## Testing Template

```dart
class _MockService extends Mock implements OpenFoodFactsService {}

void main() {
  late _MockService mockService;
  
  setUp(() => mockService = _MockService());
  
  test('success', () async {
    when(() => mockService.lookupBarcode(any()))
        .thenAnswer((_) async => ExtractionResult(
          type: 'barcode',
          data: {'product_name': 'Milk'},
          confidence: 0.95,
          warnings: [],
        ));
    
    final result = await mockService.lookupBarcode('123');
    expect(result.data['product_name'], 'Milk');
  });
  
  test('error', () async {
    when(() => mockService.lookupBarcode(any()))
        .thenThrow(BarcodeException(
          code: 'not_found',
          message: 'Product not found',
        ));
    
    expect(
      () => mockService.lookupBarcode('999'),
      throwsA(isA<BarcodeException>()),
    );
  });
}
```

---

## Common Patterns

### Show Confidence Badge

```dart
Widget _confidenceBadge(double confidence) {
  return Chip(
    label: Text('${(confidence * 100).toInt()}% confident'),
    backgroundColor: confidence >= 0.95 ? Colors.green : Colors.blue,
  );
}
```

### Warn on Cache Staleness

```dart
if (result.confidence < 0.95) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Data from Cache'),
      content: const Text('This may be outdated.'),
    ),
  );
}
```

### Store in Attachment

```dart
final attachment = Attachment(
  extractionType: result.type,           // 'barcode'
  extractionData: result.data,           // {product_name, ...}
  extractionConfidence: result.confidence, // 0.95
  // ... other fields
);
await attachmentRepository.add(attachment);
```

---

## Performance Expectations

| Scenario | Time |
|----------|------|
| Cache hit | <10ms |
| API success | 200–500ms |
| API with 1 retry | 1–1.5s |
| Timeout (10s) | 10s |

---

## Dependency Injection

### Production

```dart
final service = OpenFoodFactsService(
  cachedProductDao: db.cachedProductDao,
  // httpClient omitted → uses real http.Client()
);
```

### Testing

```dart
final service = OpenFoodFactsService(
  cachedProductDao: mockCachedProductDao,
  httpClient: mockHttpClient,
);
```

---

## File Locations

| File | Purpose |
|------|---------|
| `/lib/.../open_food_facts_service.dart` | Service implementation |
| `/test/.../open_food_facts_service_test.dart` | 14 unit tests |
| `/docs/BARCODE_API_SPEC.md` | Full API reference |
| `/BARCODE_INTEGRATION_GUIDE.md` | Integration guide |
| `/T2_BARCODE_SERVICE_REPORT.md` | Implementation report |

---

## API Endpoint

```
GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json
```

- Timeout: 10 seconds
- Retry: 1s, 2s delays (3 attempts max)
- Rate limit: ~100 req/min

---

## Don'ts

❌ Don't retry on 404 (product genuinely doesn't exist)  
❌ Don't retry on 429 (violates rate limit policy)  
❌ Don't treat cache (0.90) as always fresh (0.95)  
❌ Don't assume optional fields exist  
❌ Don't ignore warnings list  

---

## Do's

✅ Do check error code, not just catch exception  
✅ Do null-check optional data fields  
✅ Do show confidence to user  
✅ Do warn when cache staleness is relevant  
✅ Do cache results for offline support  

---

## Contact

Questions? See:
- `/docs/BARCODE_API_SPEC.md` — Full spec
- `/BARCODE_INTEGRATION_GUIDE.md` — Detailed guide
- Service source code — Inline comments

All tests passing. Service is production-ready.
