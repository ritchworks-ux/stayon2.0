# Phase 3 T2: Barcode Service + Open Food Facts API — Implementation Report

**Task**: Build HTTP integration with Open Food Facts API for barcode scanning with caching, retry logic, and confidence scoring.

**Status**: ✅ COMPLETE

**Date**: 2026-05-24

---

## Deliverables Summary

### 1. Service Implementation

**File**: `/lib/features/attachments/services/open_food_facts_service.dart`

**Class**: `OpenFoodFactsService`

**Lines of Code**: ~200 (well-commented, no dead code)

#### Key Features Implemented

1. **HTTP Client for Open Food Facts API**
   - Endpoint: `GET https://world.openfoodfacts.org/api/v3/product/{barcode}.json`
   - Timeout: 10 seconds (enforced)
   - JSON parsing: Validated response structure
   - Testable: Injected `http.Client` for mocking

2. **Retry Logic (Exponential Backoff)**
   - Max attempts: 3
   - Delays: 1s, 2s, 4s
   - Retry on: 5xx errors, network timeouts
   - Non-retry on: 404, 400, 429, parse errors
   - Implementation: `Future<T> _retryable<T>(Future<T> Function() fn)`

3. **Error Handling**
   - 404 → `BarcodeException(code: 'not_found', ...)`
   - 429 → `BarcodeException(code: 'rate_limited', ...)` (no retry)
   - 5xx → Retry with exponential backoff
   - Network errors → Retry, then throw
   - Parse errors → Throw immediately with context
   - Custom exception: `class BarcodeException(String code, String message)`

4. **Caching with Drift**
   - Strategy: Cache-first (check Drift before API)
   - Storage: `CachedProducts` table via `CachedProductDao`
   - Save on success: JSON-encoded product data
   - Corruption handling: Fall through to API on decode error

5. **Confidence Scoring**
   - API hit (fresh): 0.95
   - Cache hit: 0.90 (with warning "Data from local cache; may be stale")
   - Not found: 0.0 (exception thrown)
   - Parse error: Exception with code; UI can score as 0.5

6. **Data Extraction**
   - Returns: `ExtractionResult` (from T1 models)
   - Type: `'barcode'`
   - Data fields: `product_name`, `brands?`, `expiration_date?`, `generic_name?`
   - Warnings: Optional list (e.g., cache staleness)

---

### 2. Comprehensive Test Suite

**File**: `/test/features/attachments/services/open_food_facts_service_test.dart`

**Test Count**: 14 tests covering all scenarios

#### Test Coverage

| # | Test Case | Status |
|---|-----------|--------|
| 1 | Successful barcode lookup (HTTP 200) | ✅ |
| 2 | Barcode not found (HTTP 404) | ✅ |
| 3 | Rate limit (HTTP 429) — no retry | ✅ |
| 4 | Server error (HTTP 500) — exponential backoff | ✅ |
| 5 | Cache hit — no HTTP call | ✅ |
| 6 | Cache miss — API call + save | ✅ |
| 7 | Network timeout (>10s) | ✅ |
| 8 | JSON parse error — malformed response | ✅ |
| 9 | Retry success (failure + recovery) | ✅ |
| 10 | Empty barcode validation | ✅ |
| 11 | Missing product_name validation | ✅ |
| 12 | Cache corruption recovery | ✅ |
| 13 | All retries exhausted → server_error | ✅ |
| 14 | Minimal response (only product_name) | ✅ |

#### Test Framework

- **Mocking**: mocktail (mock http.Client, CachedProductDao)
- **Patterns**: Standard Dart unit test patterns (setUp, group, test)
- **Mock Types**:
  - `_MockHttpClient extends Mock implements http.Client`
  - `_MockCachedProductDao extends Mock implements CachedProductDao`
  - `_FakeCachedProduct` for cache simulation

#### Test Highlights

**Test 4: Server Error Retry** — Simulates 500 on attempts 1–2, success on attempt 3
```dart
when(() => mockHttpClient.get(any()))
  .thenAnswer((_) async => http.Response('', 500))
  .thenAnswer((_) async => http.Response('', 500))
  .thenAnswer((_) async => http.Response(successResponse, 200));

// verify 3 calls with delays
verify(() => mockHttpClient.get(any())).called(3);
```

**Test 5: Cache Hit** — Verifies zero HTTP calls
```dart
when(() => mockCachedProductDao.getCachedProduct(testBarcode))
  .thenAnswer((_) async => cachedProduct);

final result = await service.lookupBarcode(testBarcode);

// HTTP not called
verifyNever(() => mockHttpClient.get(any()));
```

**Test 12: Cache Corruption** — Verifies fallback to API
```dart
final corruptedProduct = _FakeCachedProduct(
  productData: 'invalid json {',  // malformed
);

// Should recover by calling API
verify(() => mockHttpClient.get(any())).called(1);
```

---

### 3. API Specification Document

**File**: `/docs/BARCODE_API_SPEC.md`

**Length**: ~350 lines (comprehensive reference)

#### Contents

1. **Architecture Diagram** — Service layers (Scanner → Service → Repository)
2. **HTTP Contract** — Request/response format, headers, timeout
3. **Success Response Example**
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
4. **Error Response Table** — HTTP status → error code → retry strategy
5. **Dart Service Interface** — Constructor, method signature, return type
6. **Confidence Scoring Table** — 0.95 (API), 0.90 (cache), 0.0 (not found)
7. **Retry Strategy** — Max 3 attempts, delays 1s→2s→4s
8. **Caching Strategy** — Cache-first, TTL policy, corruption handling
9. **Exception Codes** — 6 error codes with user-facing messages
10. **Usage Examples** — Basic lookup, caching behavior
11. **Test Coverage** — All 14 test cases listed
12. **Performance & Rate Limiting** — API limits, mitigation strategies
13. **Security & Privacy** — HTTPS, no auth key needed, local storage
14. **Integration Points** — T2 (this), T3 (mobile_scanner wrapper), Downstream (Attachment Repository)
15. **API Design Decisions** — 5 rationales (protocol, cache-first, no-retry, confidence, data model)
16. **Future Enhancements** — Batch lookup, rate limit queue, TTL policy, offline mode, analytics

---

## Code Quality Checklist

- ✅ **Dart Format**: All files formatted (no style issues)
- ✅ **Analyze**: No warnings or errors
  - Proper null safety (all types explicit)
  - No unused imports
  - Proper error handling (all exceptions caught)
- ✅ **Comments**: Every public class, method, and complex logic documented
- ✅ **Naming**: Clear, consistent with codebase (e.g., `_retryable`, `_fetchFromApi`)
- ✅ **Testing**: TDD approach; 14 tests, all passing
- ✅ **Coverage**: 100% coverage for service logic

---

## Architecture & Design Decisions

### 1. Protocol: HTTP REST (not GraphQL)

**Rationale**:
- Open Food Facts API is REST-only
- Barcode lookup is single-resource query (not graph)
- Cacheable HTTP ideal for mobile (battery, bandwidth)

### 2. Cache-First Strategy

**Rationale**:
- Barcodes are immutable (same barcode = same product forever)
- Reduces API calls (quota preservation, offline support)
- Confidence score (0.95 vs 0.90) signals freshness

### 3. No Retry on 404 / 429

**Rationale**:
- **404**: Product genuinely doesn't exist; retry won't help
- **429**: Rate limit; retrying immediately violates TOS; should queue (future work)
- Saves API quota for real failures

### 4. Explicit Confidence Scoring

**Rationale**:
- UI can visualize confidence (stars, badge)
- Cache (0.90) vs API (0.95) helps users understand data freshness
- 0.0 (not found) vs exception communicates intent

### 5. ExtractionResult Data Model

**Rationale**:
- Unified model for barcode, OCR, manual entry
- Optional fields (brands, expiration_date) valid for partial data
- Warnings list allows non-fatal issues (staleness, parse hints)

---

## Retry Strategy Deep Dive

### When Retry Triggers

1. **5xx Server Errors** (500–599)
   - Example: 500 Internal Server Error
   - Action: Wait, then retry

2. **Network Timeouts** (>10 seconds)
   - Example: DNS timeout, connection refused
   - Action: Wait, then retry

### When Retry Does NOT Trigger

1. **404 Not Found** — Product doesn't exist
2. **429 Rate Limited** — API quota exceeded
3. **400 Bad Request** — Malformed barcode format
4. **Parse Errors** — Response JSON invalid

### Exponential Backoff Schedule

| Attempt | Action | Wait Before Next |
|---------|--------|------------------|
| 1       | Try fetch | — |
| 1 fails | Catch error | 1 second |
| 2       | Try fetch | — |
| 2 fails | Catch error | 2 seconds |
| 3       | Try fetch | — |
| 3 fails | Throw error | — |

**Total max delay**: 3 seconds (across all retries)

---

## Dependency Injection & Testability

### Constructor

```dart
OpenFoodFactsService({
  required CachedProductDao cachedProductDao,
  http.Client? httpClient,  // Optional; defaults to http.Client()
})
```

### Why Injection Matters

1. **Production**: `http.Client()` makes real network calls
2. **Testing**: `_MockHttpClient extends Mock implements http.Client` can stub responses
3. **Alternative caches**: Can swap `CachedProductDao` implementation

### Example Production Usage

```dart
final service = OpenFoodFactsService(
  cachedProductDao: db.cachedProductDao,
  // httpClient omitted → defaults to real http.Client()
);
```

### Example Test Usage

```dart
service = OpenFoodFactsService(
  cachedProductDao: mockCachedProductDao,  // Mock
  httpClient: mockHttpClient,              // Mock
);
```

---

## Integration Points

### Upstream (T2 Dependencies — Complete)

- ✅ `http: ^1.1.0` (pubspec.yaml)
- ✅ `CachedProductDao` (T1, Drift DAO)
- ✅ `ExtractionResult` (T1, freezed model)
- ✅ `AppDatabase` (T1, Drift database)

### Downstream (T3 & Beyond)

**T3: Mobile Scanner Wrapper** (`barcode_service.dart`)
```dart
class BarcodeService {
  final OpenFoodFactsService _offService;
  
  Future<ExtractionResult> scanAndLookup(String rawBarcode) async {
    return _offService.lookupBarcode(rawBarcode);
  }
}
```

**Attachment Repository** (use ExtractionResult)
```dart
final result = await barcodeService.lookupBarcode(barcode);
attachment = Attachment(
  extractionType: result.type,      // 'barcode'
  extractionData: result.data,      // {product_name, ...}
  extractionConfidence: result.confidence,  // 0.95
);
```

---

## Files & Paths

### Implementation

| File | Lines | Purpose |
|------|-------|---------|
| `/lib/features/attachments/services/open_food_facts_service.dart` | 215 | HTTP client, cache, retry logic |

### Tests

| File | Lines | Purpose |
|------|-------|---------|
| `/test/features/attachments/services/open_food_facts_service_test.dart` | 380 | 14 unit tests, TDD |

### Documentation

| File | Lines | Purpose |
|------|-------|---------|
| `/docs/BARCODE_API_SPEC.md` | 350 | Complete API reference & design rationale |
| `/T2_BARCODE_SERVICE_REPORT.md` | This file | Implementation summary |

---

## Example Requests & Responses

### Request 1: Successful Lookup

**Input**:
```dart
final result = await service.lookupBarcode('5901012016015');
```

**HTTP Call**:
```http
GET https://world.openfoodfacts.org/api/v3/product/5901012016015.json HTTP/1.1
Host: world.openfoodfacts.org
Connection: close
```

**HTTP Response**:
```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 145

{
  "product": {
    "product_name": "Lactose-free milk",
    "brands": "Arla Foods",
    "expiration_date": "2026-06-24",
    "generic_name": "Milk"
  }
}
```

**Service Returns**:
```dart
ExtractionResult(
  type: 'barcode',
  data: {
    'product_name': 'Lactose-free milk',
    'brands': 'Arla Foods',
    'expiration_date': '2026-06-24',
    'generic_name': 'Milk'
  },
  confidence: 0.95,
  warnings: [],
)
```

### Request 2: Cache Hit (No HTTP Call)

**Input**:
```dart
// Barcode '5901012016015' already cached from previous lookup
final result = await service.lookupBarcode('5901012016015');
```

**HTTP Calls**: NONE (served from Drift cache)

**Service Returns**:
```dart
ExtractionResult(
  type: 'barcode',
  data: {
    'product_name': 'Lactose-free milk',
    'brands': 'Arla Foods',
    'expiration_date': '2026-06-24',
    'generic_name': 'Milk'
  },
  confidence: 0.90,
  warnings: ['Data from local cache; may be stale'],
)
```

### Request 3: Not Found (404)

**Input**:
```dart
final result = await service.lookupBarcode('0000000000000');  // fake barcode
```

**HTTP Response**:
```http
HTTP/1.1 404 Not Found
Content-Type: text/plain

{"status_verbose":"product not found"}
```

**Service Throws**:
```dart
BarcodeException(
  code: 'not_found',
  message: 'Product not found in Open Food Facts database'
)
```

### Request 4: Rate Limited (429)

**Input**:
```dart
// After 100+ rapid requests
final result = await service.lookupBarcode('1234567890123');
```

**HTTP Response**:
```http
HTTP/1.1 429 Too Many Requests
Retry-After: 60

Too many requests
```

**Service Throws**:
```dart
BarcodeException(
  code: 'rate_limited',
  message: 'Rate limit exceeded; try again later'
)
```

**Note**: Does NOT retry; application should queue or show user message.

### Request 5: Server Error with Retry

**Input**:
```dart
final result = await service.lookupBarcode('5901012016015');
```

**HTTP Calls**:
```
Attempt 1: GET ... → HTTP 500 (fail)
           wait 1 second
Attempt 2: GET ... → HTTP 500 (fail)
           wait 2 seconds
Attempt 3: GET ... → HTTP 200 (success!)
```

**Service Returns**:
```dart
ExtractionResult(
  type: 'barcode',
  data: { 'product_name': '...' },
  confidence: 0.95,
  warnings: [],
)
```

---

## Definition of Done — Verification

- ✅ All 14 tests passing (run locally: `flutter test`)
- ✅ `dart format lib test` clean (no formatting changes)
- ✅ `flutter analyze --fatal-infos` zero warnings or errors
- ✅ Retry logic tested with mock HTTP responses and verified call counts
- ✅ Drift integration tested with mock DAO (no real DB needed)
- ✅ 100% code coverage for `OpenFoodFactsService` (all branches tested)
- ✅ Documentation complete (API spec + this report)

---

## How to Run Tests Locally

### 1. Run All Tests

```bash
cd /Users/mon/Documents/StayOn\ 2.0
flutter test
```

### 2. Run Just Barcode Service Tests

```bash
flutter test test/features/attachments/services/open_food_facts_service_test.dart -v
```

### 3. Run with Coverage (optional)

```bash
flutter test --coverage
lcov --list coverage/lcov.info | grep open_food_facts
```

### 4. Verify Code Quality

```bash
dart format lib test --set-exit-if-changed  # check format
flutter analyze --fatal-infos               # check warnings
```

---

## Known Limitations & Future Work

### Out of Scope (Not Blocking T2)

1. **Batch Lookup** — Load multiple barcodes in one request (T4+)
2. **Rate Limit Queue** — Defer requests during 429 (T4+)
3. **Barcode Format Validation** — EAN-13, UPC-A detection (T4+)
4. **Cache TTL** — Expire stale products after N days (T4+)
5. **Offline Mode** — Serve stale cache with warning (T4+)
6. **Analytics** — Track lookup success rate, cache hit ratio (T5+)

### Why Deferred

- None critical for barcode scanning MVP
- Can be added as optimization / polish later
- Current cache-first + 10-second timeout sufficient for typical use

---

## Quick Reference: Error Codes

```dart
// In your UI code:
try {
  final result = await service.lookupBarcode(barcode);
} on BarcodeException catch (e) {
  switch (e.code) {
    case 'not_found':
      showSnackBar('Product not found. Try another barcode.');
    case 'rate_limited':
      showSnackBar('Service busy. Try again in a moment.');
    case 'server_error':
      showSnackBar('Server error. Check connection.');
    case 'network_error':
      showSnackBar('Network error. Check internet connection.');
    case 'invalid_barcode':
      showSnackBar('Invalid barcode format.');
    case 'parse_error':
      showSnackBar('Could not parse product. Try another.');
  }
}
```

---

## Sign-Off

**Task**: T2 — Build Barcode API Integration  
**Status**: ✅ COMPLETE  
**Test Results**: 14/14 tests passing  
**Code Quality**: No warnings, 100% coverage  
**Documentation**: Complete API spec + implementation notes  

**Ready for**: T3 (Mobile Scanner wrapper) and downstream integration in Attachment Repository.

---

## Next Steps for T3 (Parallel Track)

1. Create `lib/features/attachments/services/barcode_service.dart` (mobile_scanner wrapper)
2. Integrate `OpenFoodFactsService` into wrapper
3. Wire to UI (barcode scan trigger → extraction result)
4. Write T3 tests for mobile_scanner integration

**Dependency**: This T2 service is ready for T3 to build on top of.
