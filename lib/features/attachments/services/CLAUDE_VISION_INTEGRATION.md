# Claude Vision API Integration (Task T6)

## Overview

`ClaudeVisionService` provides structured OCR extraction for receipt images using Anthropic's Claude 3.5 Sonnet model with vision capabilities.

**Extracts:** date (YYYY-MM-DD) + amount (cents)
**Output:** ExtractionResult with confidence (0.75–0.95) and warnings array

## Architecture

### Class Hierarchy
```
OcrService (abstract interface)
  └── ClaudeVisionService (concrete implementation)
```

### Key Components

| File | Purpose |
|------|---------|
| `ocr_service.dart` | Abstract interface for OCR services (extensible for other providers) |
| `claude_vision_service.dart` | Anthropic Claude Vision API client with retry logic |

### Dependency Injection

```dart
// Create service instance
final service = ClaudeVisionService(
  httpClient: http.Client(), // optional, for DI
  apiKey: 'sk-ant-...', // optional, reads from Env.anthropicApiKey
);

// Use it
final result = await service.extractReceiptData(imageBytes);
```

## API Integration Details

### Request Format

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Headers:**
```
x-api-key: {ANTHROPIC_API_KEY}
anthropic-version: 2023-06-01
content-type: application/json
```

**Body:**
```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 500,
  "messages": [
    {
      "role": "user",
      "content": [
        {
          "type": "image",
          "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": "<base64-encoded-bytes>"
          }
        },
        {
          "type": "text",
          "text": "Extract from this receipt:\n- Date (YYYY-MM-DD format)\n- Amount (total cost in cents, integer)\n\nReturn JSON only..."
        }
      ]
    }
  ]
}
```

### Response Format

**Expected Success (200 OK):**
```json
{
  "content": [
    {
      "type": "text",
      "text": "{\n  \"date\": \"2026-05-24\",\n  \"amount_cents\": 4599,\n  \"warnings\": []\n}"
    }
  ]
}
```

### Error Handling

| HTTP Status | Code | Behavior | Retry |
|-------------|------|----------|-------|
| 401 | `auth_failed` | Invalid API key | No |
| 429 | `rate_limited` | API rate limit | Yes (3x with backoff) |
| 5xx | `server_error` | API server error | Yes (3x with backoff) |
| 4xx (exc 429) | `invalid_request` | Bad image format, oversized | No |
| Timeout | `network_error` | 30s timeout | No |
| JSON Parse | `parse_failed` | Malformed response | No |

**Retry Strategy:** Exponential backoff: 1s, 2s, 4s

## Integration with ReceiptPhotoSheet (Task #5)

### Current State (Task #5 Complete)

`ReceiptPhotoSheet` widget is ready with placeholders for OCR integration:
- Compresses image to < 1 MB
- Shows success state with editable date/amount fields
- Passes image bytes to `onPhotoAttached` callback

### Integration Pattern (Task #6 Implementation)

In `ReceiptPhotoSheet._processImage()`, after image compression:

```dart
void _processImage(File imageFile) async {
  setState(() {
    _state = _ReceiptPhotoState.loading;
    _errorMessage = null;
  });

  try {
    // 1. Compress image (already done)
    final compressedBytes = await _compressionService.compressImage(imageFile);

    // 2. Extract via Claude Vision (NEW)
    final ocrService = ClaudeVisionService();
    final extractionResult = await ocrService.extractReceiptData(compressedBytes);

    // 3. Populate form fields
    if (extractionResult.data['date'] != null) {
      final date = DateTime.parse(extractionResult.data['date'] as String);
      _dateController.text = _formatDate(date);
      _extractedDate = date;
    }

    if (extractionResult.data['amount_cents'] != null) {
      final cents = extractionResult.data['amount_cents'] as int;
      _amountController.text = (cents / 100).toStringAsFixed(2);
    }

    // 4. Store confidence (for Task #7: extraction review UI)
    _extractedConfidence = extractionResult.confidence;
    _extractionWarnings = extractionResult.warnings;

    setState(() {
      _selectedImage = imageFile;
      _state = _ReceiptPhotoState.success;
    });

    await HapticFeedback.lightImpact();
  } on CompressionException catch (e) {
    _handleError(e.message);
  } on OcrException catch (e) {
    _handleError('Extraction failed: ${e.message}');
  } catch (e) {
    _handleError('Unexpected error: $e');
  }
}
```

## Confidence Scoring

| Warnings | Confidence | Meaning |
|----------|------------|---------|
| 0 | 0.95 | High confidence; both fields extracted cleanly |
| 1 | 0.85 | Medium confidence; minor issue (e.g., "blurry") |
| 2+ | 0.75 | Lower confidence; multiple issues or missing fields |

## Input Validation

### Image Bytes
- **Empty:** Rejected with code `invalid_request`
- **Oversized (> 1 MB):** Rejected with code `invalid_request`
  - Ensure caller compresses before passing (Task #5 handles this)
- **Format:** JPEG expected (specified in base64 source)

### API Key
- **Missing:** Reads from `Env.anthropicApiKey` (loaded from `.env.local`)
- **Invalid:** Returns 401; raises `OcrException('auth_failed', ...)`

## Environment Setup

### .env.local

```
ANTHROPIC_API_KEY=sk-ant-v8-...your-key-here...
```

**To get API key:**
1. Visit https://console.anthropic.com/
2. Navigate to API Keys
3. Create new key
4. Paste into .env.local

**Running with env var:**
```bash
flutter run --dart-define-from-file=.env.local
```

## Testing

### Unit Tests (11+ tests in `claude_vision_service_test.dart`)

Covers:
- ✅ Successful extraction (date + amount)
- ✅ Missing date/amount handling
- ✅ Warning handling (single, multiple)
- ✅ Empty/oversized image rejection
- ✅ 401 Unauthorized
- ✅ 429 Rate Limit (retry logic)
- ✅ 500 Server Error (retry logic)
- ✅ 400 Bad Request
- ✅ Network timeout
- ✅ JSON parse error
- ✅ Confidence scoring (0.95, 0.85, 0.75)

**Run tests:**
```bash
flutter test test/features/attachments/services/claude_vision_service_test.dart
```

### Mocking in Widget Tests

When testing `ReceiptPhotoSheet` integration, mock the OCR service:

```dart
final mockOcrService = MockOcrService();
when(() => mockOcrService.extractReceiptData(any())).thenAnswer(
  (_) async => ExtractionResult(
    type: 'receipt',
    data: {'date': '2026-05-24', 'amount_cents': 4599},
    confidence: 0.95,
    warnings: [],
  ),
);

// Pass via constructor or via provider
```

## Performance Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| Image compression | < 500ms | Already handled by Task #5 |
| Claude Vision API call | < 3s | Network + Claude processing |
| Total extraction (compress + OCR) | < 4s | User-facing timeout |

## Troubleshooting

### 401 Unauthorized
**Cause:** Invalid or missing API key
**Fix:** Check `ANTHROPIC_API_KEY` in `.env.local`, regenerate if needed

### 429 Rate Limit
**Cause:** Too many API calls in short time
**Fix:** Service auto-retries 3 times; if still fails, wait a moment before retrying

### Parse Failed
**Cause:** Claude Vision returned unexpected format
**Fix:** Check response structure; verify Claude model version

### Timeout
**Cause:** Network slow or Claude Vision unresponsive
**Fix:** Increase timeout constant `_requestTimeoutSeconds`, or retry user action

## Next Steps (Task #7)

1. **Extraction Review UI:** Display confidence badge + warning list to user
   - Show "High confidence" (0.95)
   - Show "Medium confidence" with warning tooltip (0.85)
   - Show "Low confidence" with edit prompt (0.75)

2. **Optional Enhancements:**
   - Cache extracted data in Drift (avoid re-extraction)
   - Add manual re-extraction button if confidence < 0.85
   - Log extraction metrics (date success %, amount success %)

## References

- **Anthropic Claude Vision:** https://docs.anthropic.com/en/docs/vision
- **OpenAPI Spec (if needed):** See project root or architecture docs
- **Task #5 (Image Compression):** `ImageCompressionService`
- **Task #7 (Extraction Review):** Will integrate this service

