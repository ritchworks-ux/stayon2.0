import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:stayon/core/config/env.dart';
import 'package:stayon/core/models/extraction_result.dart';
import 'package:stayon/features/attachments/services/ocr_service.dart';

/// HTTP client for Claude Vision API with retry logic and structured extraction.
///
/// Features:
/// - Base64 image encoding (max 1 MB, pre-compressed)
/// - Structured JSON extraction: date (YYYY-MM-DD), amount_cents (integer)
/// - Confidence scoring: 0.95 (no warnings), 0.85 (1 warning), 0.75 (2+ warnings)
/// - Exponential backoff retry: 1s, 2s, 4s on rate limits and server errors
/// - Explicit error handling: OcrException with typed codes
/// - Input validation: empty/oversized image rejection
///
/// API Contract:
/// - Endpoint: POST https://api.anthropic.com/v1/messages
/// - Headers: x-api-key, anthropic-version, content-type
/// - Model: claude-3-5-sonnet-20241022
/// - Max tokens: 500 (for JSON response)
///
/// Example Usage:
/// ```dart
/// final service = ClaudeVisionService();
/// try {
///   final result = await service.extractReceiptData(imageBytes);
///   print(result.data['date']); // "2026-05-24" or null
///   print(result.data['amount_cents']); // 4599 or null
///   print(result.confidence); // 0.95
/// } on OcrException catch (e) {
///   print('OCR failed: ${e.code} - ${e.message}');
/// }
/// ```
class ClaudeVisionService extends OcrService {
  ClaudeVisionService({http.Client? httpClient, String? apiKey})
    : _httpClient = httpClient ?? http.Client(),
      _apiKey = apiKey ?? Env.anthropicApiKey;

  static const _apiUrl = 'https://api.anthropic.com/v1/messages';
  static const _anthropicVersion = '2023-06-01';
  static const _model = 'claude-3-5-sonnet-20241022';
  static const _maxTokens = 500;
  static const int _maxImageSizeBytes = 1024 * 1024; // 1 MB
  static const _maxRetries = 3;
  static const List<Duration> _retryDelays = [
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
  ];
  static const _requestTimeoutSeconds = 30;

  final http.Client _httpClient;
  final String _apiKey;

  /// Extract structured data from receipt image.
  ///
  /// Input validation:
  /// - Image bytes must not be empty
  /// - Image size must be <= 1 MB (assume pre-compressed)
  ///
  /// Returns [ExtractionResult] with:
  /// - type: 'receipt'
  /// - data: {date: "YYYY-MM-DD"?, amount_cents: integer?}
  /// - confidence: calculated from warnings count
  /// - warnings: from Claude Vision response (e.g., "date unclear")
  ///
  /// Throws [OcrException] on:
  /// - Empty/oversized image
  /// - API authentication failure (401)
  /// - Rate limiting (429) after 3 retries
  /// - Server error (5xx) after 3 retries
  /// - Network timeout
  /// - JSON parse failure
  @override
  Future<ExtractionResult> extractReceiptData(Uint8List imageBytes) async {
    // Validate input
    _validateImageInput(imageBytes);

    // Base64 encode
    final base64Image = base64Encode(imageBytes);

    // Call API with retry logic
    final responseText = await _retryable(() => _callClaudeVision(base64Image));

    // Parse response JSON
    return _parseExtractionResponse(responseText);
  }

  /// Validate image input bytes.
  void _validateImageInput(Uint8List imageBytes) {
    if (imageBytes.isEmpty) {
      throw OcrException(
        code: 'invalid_request',
        message: 'Image bytes cannot be empty',
      );
    }

    if (imageBytes.lengthInBytes > _maxImageSizeBytes) {
      throw OcrException(
        code: 'invalid_request',
        message:
            'Image size (${imageBytes.lengthInBytes} bytes) exceeds max of 1 MB. '
            'Ensure image is pre-compressed.',
      );
    }
  }

  /// Call Claude Vision API with structured prompt.
  ///
  /// Returns the text content from the first message in the response.
  ///
  /// Throws [OcrException] on authentication, server, or network errors.
  Future<String> _callClaudeVision(String base64Image) async {
    final requestBody = {
      'model': _model,
      'max_tokens': _maxTokens,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': 'image/jpeg',
                'data': base64Image,
              },
            },
            {'type': 'text', 'text': _buildExtractionPrompt()},
          ],
        },
      ],
    };

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'x-api-key': _apiKey,
              'anthropic-version': _anthropicVersion,
              'content-type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(
            const Duration(seconds: _requestTimeoutSeconds),
            onTimeout: () {
              throw OcrException(
                code: 'network_error',
                message:
                    'Request timeout after $_requestTimeoutSeconds seconds',
              );
            },
          );

      // Handle 401: authentication failure
      if (response.statusCode == 401) {
        throw OcrException(
          code: 'auth_failed',
          message:
              'Claude Vision API authentication failed. Check ANTHROPIC_API_KEY.',
        );
      }

      // Handle 429: rate limit (do NOT retry via this method; caller handles retry)
      if (response.statusCode == 429) {
        throw OcrException(
          code: 'rate_limited',
          message: 'Claude Vision API rate limit exceeded; retry in a moment',
        );
      }

      // Handle 5xx: server error (will be retried by caller)
      if (response.statusCode >= 500) {
        throw OcrException(
          code: 'server_error',
          message: 'Claude Vision API server error (${response.statusCode})',
        );
      }

      // Handle other 4xx: bad request (image format, etc.)
      if (response.statusCode >= 400) {
        throw OcrException(
          code: 'invalid_request',
          message:
              'Claude Vision API rejected request (${response.statusCode}): ${response.body}',
        );
      }

      // Parse successful response
      if (response.statusCode != 200) {
        throw OcrException(
          code: 'server_error',
          message: 'Unexpected HTTP status ${response.statusCode}',
        );
      }

      return _extractResponseText(response.body);
    } on OcrException {
      rethrow;
    } catch (e) {
      throw OcrException(code: 'network_error', message: 'Network error: $e');
    }
  }

  /// Extract text content from Claude API response.
  ///
  /// Expected structure:
  /// ```json
  /// {
  ///   "content": [
  ///     {"type": "text", "text": "{...extracted JSON...}"}
  ///   ]
  /// }
  /// ```
  String _extractResponseText(String responseBody) {
    try {
      final response = jsonDecode(responseBody) as Map<String, dynamic>;
      final content = response['content'] as List<dynamic>?;

      if (content == null || content.isEmpty) {
        throw OcrException(
          code: 'parse_failed',
          message: 'Claude Vision response missing content array',
        );
      }

      final firstContent = content[0] as Map<String, dynamic>?;
      if (firstContent == null) {
        throw OcrException(
          code: 'parse_failed',
          message: 'Claude Vision response content[0] is null',
        );
      }

      final text = firstContent['text'] as String?;
      if (text == null || text.isEmpty) {
        throw OcrException(
          code: 'parse_failed',
          message: 'Claude Vision response content[0].text is null or empty',
        );
      }

      return text;
    } on OcrException {
      rethrow;
    } catch (e) {
      throw OcrException(
        code: 'parse_failed',
        message: 'Failed to parse Claude Vision API response: $e',
      );
    }
  }

  /// Parse extraction response JSON.
  ///
  /// Expected JSON structure from Claude Vision:
  /// ```json
  /// {
  ///   "date": "2026-05-24",
  ///   "amount_cents": 4599,
  ///   "warnings": ["date unclear"]
  /// }
  /// ```
  ///
  /// - date: YYYY-MM-DD format (validated), or null if not found/invalid
  /// - amount_cents: positive integer, or null if not found
  /// - warnings: array of strings, defaults to []
  ///
  /// Confidence scoring:
  /// - 0.95 if no warnings
  /// - 0.85 if 1 warning
  /// - 0.75 if 2+ warnings
  ExtractionResult _parseExtractionResponse(String responseText) {
    try {
      // Parse JSON from Claude Vision response
      final extractedJson = jsonDecode(responseText) as Map<String, dynamic>;

      // Extract date (validate YYYY-MM-DD format)
      final dateStr = extractedJson['date'] as String?;
      DateTime? date;
      final dateWarnings = <String>[];

      if (dateStr != null && dateStr.isNotEmpty) {
        try {
          date = DateTime.parse(dateStr);
          // Validate format is exactly YYYY-MM-DD
          if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
            dateWarnings.add('date format invalid; expected YYYY-MM-DD');
            date = null;
          }
        } catch (_) {
          dateWarnings.add('date could not be parsed');
          date = null;
        }
      }

      // Extract amount_cents (must be positive integer)
      int? amountCents;
      final amountWarnings = <String>[];

      final amountValue = extractedJson['amount_cents'];
      if (amountValue != null) {
        try {
          if (amountValue is int) {
            amountCents = amountValue;
          } else if (amountValue is double) {
            amountCents = amountValue.toInt();
          } else {
            amountCents = int.parse(amountValue.toString());
          }

          if (amountCents != null && amountCents < 0) {
            amountWarnings.add('amount is negative');
            amountCents = null;
          }
        } catch (_) {
          amountWarnings.add('amount_cents could not be parsed as integer');
          amountCents = null;
        }
      }

      // Extract warnings from API response
      final apiWarnings =
          (extractedJson['warnings'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          [];

      // Combine all warnings
      final allWarnings = [...dateWarnings, ...amountWarnings, ...apiWarnings];

      // Calculate confidence
      final confidence = _calculateConfidence(allWarnings.length);

      return ExtractionResult(
        type: 'receipt',
        data: {
          if (date != null) 'date': date.toIso8601String().split('T')[0],
          if (amountCents != null) 'amount_cents': amountCents,
        },
        confidence: confidence,
        warnings: allWarnings,
      );
    } on OcrException {
      rethrow;
    } catch (e) {
      throw OcrException(
        code: 'parse_failed',
        message: 'Failed to parse extraction JSON: $e',
      );
    }
  }

  /// Calculate confidence score based on warning count.
  ///
  /// - 0.95 if no warnings
  /// - 0.85 if 1 warning
  /// - 0.75 if 2+ warnings
  double _calculateConfidence(int warningCount) {
    return switch (warningCount) {
      0 => 0.95,
      1 => 0.85,
      _ => 0.75,
    };
  }

  /// Build extraction prompt for Claude Vision.
  String _buildExtractionPrompt() => '''Extract from this receipt:
- Date (invoice date, format YYYY-MM-DD)
- Amount (total cost in cents, as integer)

Return JSON only:
{
  "date": "2026-05-24",
  "amount_cents": 4599,
  "warnings": ["date unclear", "amount partially obscured"]
}

If you cannot extract a field, set it to null (not "null" string).
Include warnings array with non-fatal issues (e.g., "blurry", "partially cut off").''';

  /// Retry logic with exponential backoff.
  ///
  /// Retries on:
  /// - 429 (rate limit)
  /// - 5xx (server errors)
  ///
  /// Does NOT retry on:
  /// - 401 (authentication)
  /// - 4xx except 429 (bad request, invalid image)
  /// - Parse errors
  /// - Network errors (timeout)
  Future<T> _retryable<T>(Future<T> Function() fn) async {
    OcrException? lastError;

    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        return await fn();
      } on OcrException catch (e) {
        // Only retry on rate limits and server errors
        if (e.code == 'rate_limited' || e.code == 'server_error') {
          lastError = e;
          if (attempt < _maxRetries - 1) {
            await Future<void>.delayed(_retryDelays[attempt]);
          }
        } else {
          // Non-retriable error: throw immediately
          rethrow;
        }
      }
    }

    // All retries exhausted
    throw lastError ??
        OcrException(
          code: 'extraction_failed',
          message: 'All retry attempts exhausted',
        );
  }
}
