# Barcode Service API Specification

## Overview

The **OpenFoodFactsService** provides HTTP integration with the Open Food Facts API, enabling barcode scanning and product lookup for items in the StayOn application.

- **Protocol**: REST (Open Food Facts API)
- **Base URL**: `https://world.openfoodfacts.org/api/v3/product`
- **Data Format**: JSON
- **Versioning**: No versioning required (uses stable v3 endpoint)

---

## Architecture

### Service Layers

```
┌─────────────────────────────────────────────────────┐
│    Mobile Scanner (T3)                              │
│    Barcode detection -> string barcode              │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│  OpenFoodFactsService (THIS FILE)                   │
│  - Cache-first lookup (Drift)                       │
│  - Retry logic (exponential backoff)                │
│  - Error handling & confidence scoring              │
└────────────────────┬────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│  Attachment Repository (T3)                         │
│  - Store extraction results                         │
│  - Link to items                                    │
└──────────────────────────────────────────────────────┘
```

---

## HTTP Contract

### Request

```http
GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json
```

**Path Parameters:**
- `barcode` (string, required): EAN-13 or other standard barcode
  - Example: `"5901012016015"`

**Headers:**
- `Accept: application/json` (implicit via http.get)
- `User-Agent`: StayOn/1.0 (recommended for API courtesy)

**Timeout**: 10 seconds (enforced client-side)

### Success Response

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "product": {
    "product_name": "Lactose-free milk",
    "brands": "Arla Foods",
    "expiration_date": "2026-06-24",
    "generic_name": "Milk"
  }
}
```

**Response Fields:**
- `product.product_name` (string, required): Product name for extraction
- `product.brands` (string, optional): Brand/manufacturer name
- `product.expiration_date` (string, ISO date, optional): E.g., "2026-06-24"
- `product.generic_name` (string, optional): Generic category

### Error Responses

| HTTP Status | Code | Meaning | Retry? |
|-------------|------|---------|--------|
| 404 | `not_found` | Product not in database | ✗ (non-retriable) |
| 429 | `rate_limited` | Rate limit exceeded | ✗ (non-retriable) |
| 5xx | `server_error` | Server error | ✓ (exponential backoff) |
| 4xx (other) | `invalid_barcode` | Bad format or client error | ✗ (non-retriable) |
| Timeout | `network_error` | Connection timeout (>10s) | ✓ (exponential backoff) |

---

## Dart Service Interface

### Class: `OpenFoodFactsService`

#### Constructor

```dart
OpenFoodFactsService({
  required CachedProductDao cachedProductDao,
  http.Client? httpClient,  // Optional for testing
})
```

**Dependencies:**
- `CachedProductDao`: Drift DAO for local product caching
- `http.Client`: HTTP client (injected for testability)

#### Method: `lookupBarcode`

```dart
Future<ExtractionResult> lookupBarcode(String barcode)
```

**Parameters:**
- `barcode` (String): EAN-13 or standard barcode

**Returns:**
```dart
ExtractionResult(
  type: 'barcode',
  data: {
    'product_name': 'Lactose-free milk',
    'brands': 'Arla Foods',
    'expiration_date': '2026-06-24',
    'generic_name': 'Milk'
  },
  confidence: 0.95,  // 0.95=API, 0.90=cache, 0.0=notfound
  warnings: [],      // ['Data from local cache; may be stale'] if cached
)
```

**Throws:**
```dart
BarcodeException(
  code: 'not_found|rate_limited|server_error|network_error|invalid_barcode|parse_error',
  message: 'Human-readable error message'
)
```

---

## Confidence Scoring

| Source | Confidence | Notes |
|--------|------------|-------|
| API (fresh lookup) | 0.95 | High confidence, current data |
| Cache (Drift hit) | 0.90 | Slightly lower; data may be stale |
| Not found (404) | 0.0 | Product does not exist (exception thrown) |
| Parse error | 0.5 | Malformed response; user should review |

---

## Retry Strategy (Exponential Backoff)

**Max Attempts**: 3

| Attempt | Wait (on failure) |
|---------|------------------|
| 1       | Initial (immediate) |
| 2       | 1 second |
| 3       | 2 seconds |
| 4 (fail)| 4 seconds (not executed) |

**Retriable Errors:**
- `server_error` (5xx HTTP status)
- `network_error` (timeout, DNS failure, etc.)

**Non-Retriable Errors** (thrown immediately):
- `not_found` (404)
- `rate_limited` (429)
- `invalid_barcode` (4xx other)
- `parse_error` (malformed JSON)

---

## Caching Strategy

### Cache-First

1. **Lookup** by barcode in Drift `cached_products` table
2. **Cache Hit**: Return cached data immediately (confidence 0.90)
3. **Cache Miss**: Call Open Food Facts API
4. **Store**: On success, save to `cached_products` with barcode key
5. **Reuse**: Subsequent lookups within session use cache

### Cache Schema

```dart
class CachedProducts extends Table {
  TextColumn get id => text()();
  TextColumn get barcode => text().unique()();
  TextColumn get productData => text().named('product_data')();  // JSON blob
  DateTimeColumn get createdAt => dateTime().named('created_at')();

  @override
  Set<Column> get primaryKey => {id};
}
```

**TTL**: Session-based (no expiry in Drift; cleared on app lifecycle)

### Cache Corruption Handling

If stored JSON cannot be decoded, the service:
1. Logs the corruption
2. Falls through to API call
3. Overwrites the corrupted entry

---

## Exception Handling

### `BarcodeException` Class

```dart
class BarcodeException implements Exception {
  final String code;      // Error category
  final String message;   // Human-readable text
}
```

**Codes & Recovery Strategies:**

| Code | Scenario | User-Facing Action |
|------|----------|-------------------|
| `not_found` | Barcode not in database | "Product not found. Try another barcode." |
| `rate_limited` | Too many requests | "Service busy. Try again in a moment." |
| `server_error` | Open Food Facts down | "Server error. Check connection." |
| `network_error` | Timeout, DNS, no internet | "Network error. Check internet connection." |
| `invalid_barcode` | Malformed barcode | "Invalid barcode format." |
| `parse_error` | Response malformed | "Could not parse product data. Try another." |

---

## Usage Example

### Basic Lookup

```dart
final service = OpenFoodFactsService(
  cachedProductDao: db.cachedProductDao,
);

try {
  final result = await service.lookupBarcode('5901012016015');
  
  print('Product: ${result.data['product_name']}');
  print('Confidence: ${result.confidence * 100}%');
  
  if (result.warnings.isNotEmpty) {
    print('Warnings: ${result.warnings.join(', ')}');
  }
} on BarcodeException catch (e) {
  print('Lookup failed: ${e.code} - ${e.message}');
}
```

### Caching Example

```dart
// First call: Cache miss, API call (confidence 0.95)
final result1 = await service.lookupBarcode('5901012016015');

// Second call: Cache hit, no API call (confidence 0.90)
final result2 = await service.lookupBarcode('5901012016015');
```

---

## Testing

### Test Coverage (14 tests)

1. ✅ Successful barcode lookup (HTTP 200)
2. ✅ Barcode not found (HTTP 404)
3. ✅ Rate limit (HTTP 429) — no retry
4. ✅ Server error (HTTP 500) — exponential backoff
5. ✅ Cache hit — no HTTP call
6. ✅ Cache miss — API call + save
7. ✅ Network timeout
8. ✅ JSON parse error
9. ✅ Retry success (failure + recovery)
10. ✅ Empty barcode validation
11. ✅ Missing product_name validation
12. ✅ Cache corruption recovery
13. ✅ All retries exhausted
14. ✅ Minimal response (only product_name)

**Test Framework**: mocktail (mock HTTP & Drift)

**Location**: `/test/features/attachments/services/open_food_facts_service_test.dart`

---

## Performance & Rate Limiting

### Open Food Facts API Limits

- **Rate Limit**: ~100 requests/minute (public API)
- **Recommendation**: Implement client-side rate limiting or cache aggressively

### Mitigation

1. **Cache-first strategy** reduces API calls
2. **429 handling** queues requests (future work in T4)
3. **Exponential backoff** respects server load

---

## Security & Privacy

### Data Handling

- **User data**: No personal information sent to Open Food Facts
- **Barcode only**: Service sends only the barcode string
- **Response storage**: Product data cached locally in encrypted Drift DB

### HTTPS

- ✅ All requests use HTTPS
- ✅ Certificate validation enabled by default

### API Key

- Open Food Facts does NOT require API key (public endpoint)
- Future: Migrate to authenticated endpoints if rate limits tighten

---

## Integration Points (T2/T3)

### T2 Current (This Document)

- HTTP client + retry logic
- Drift caching
- ExtractionResult mapping

### T3 Next (barcode_service.dart)

```dart
// Mobile scanner wrapper
class BarcodeService {
  final OpenFoodFactsService _offfService;
  
  Future<ExtractionResult> scanAndLookup(BarcodeCapture scan) async {
    return _offfService.lookupBarcode(scan.rawValue);
  }
}
```

### Downstream (Attachment Repository)

```dart
// Save extraction result to Attachment
attachment = Attachment(
  extractionType: result.type,
  extractionData: result.data,
  extractionConfidence: result.confidence,
);
```

---

## API Design Decisions

### 1. **Protocol: HTTP REST** (not GraphQL)

**Rationale**:
- Open Food Facts provides REST API only
- Mobile app needs simple, cacheable HTTP (efficient for low-bandwidth)
- Barcode lookup is a single-resource query (not multi-resource graph)

### 2. **Cache-First Strategy**

**Rationale**:
- Barcodes are immutable (same barcode = same product)
- Reduces API calls, improves offline support
- Confidence score signals freshness to UI

### 3. **No Retry on 404 / 429**

**Rationale**:
- 404: Product genuinely not found; retrying won't help
- 429: Rate limit; must backoff exponentially (already retrying 5xx)
- Saves API quota for real failures

### 4. **Confidence Scoring**

**Rationale**:
- UI can show confidence as visual indicator (stars, badge)
- Cache hit (0.90) vs. API (0.95) helps users trust data freshness
- Explicit failure reasons (code) enable specific UX messaging

### 5. **ExtractionResult Type**

**Rationale**:
- Unified data model for barcode, OCR, and manual entry
- Optional fields (brands, expiration_date) make partial data valid
- Warnings list allows non-fatal issues (cache staleness, parse hints)

---

## File Paths

**Service Implementation**:
- `/lib/features/attachments/services/open_food_facts_service.dart`

**Tests**:
- `/test/features/attachments/services/open_food_facts_service_test.dart`

**Database DAO**:
- `/lib/core/database/cached_product_dao.dart`

**Models**:
- `/lib/core/models/extraction_result.dart`

---

## Future Enhancements (Out of Scope - T4+)

- [ ] Batch barcode lookup (multiple barcodes in one request)
- [ ] Rate limit queue (defer requests during 429)
- [ ] Barcode format validation (EAN-13, UPC-A detection)
- [ ] Cache TTL policy (expiration after N days)
- [ ] Offline mode (serve stale cache with warning)
- [ ] Analytics (lookup success rate, cache hit ratio)
