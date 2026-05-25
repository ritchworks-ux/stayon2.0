import 'dart:typed_data';
import 'package:stayon/core/models/extraction_result.dart';

/// Exception thrown during OCR operations.
class OcrException implements Exception {
  OcrException({required this.code, required this.message});

  /// Error code: 'auth_failed', 'rate_limited', 'invalid_request', 'server_error',
  /// 'network_error', 'parse_failed', 'extraction_failed'
  final String code;

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'OcrException($code): $message';
}

/// Abstract interface for OCR services (e.g., Claude Vision, Google ML Kit, Tesseract).
///
/// Implementations should handle image compression validation, API integration,
/// retry logic, and error handling consistently.
abstract class OcrService {
  /// Extract structured data from receipt image.
  ///
  /// Returns [ExtractionResult] with:
  /// - type: 'receipt'
  /// - data: {date?, amount_cents?} (keys may be null if extraction failed)
  /// - confidence: 0.0–1.0 (0.95 no warnings, 0.85 one warning, 0.75 two+ warnings)
  /// - warnings: List of non-fatal issues (e.g., "date unclear")
  ///
  /// Throws [OcrException] on unrecoverable errors (auth, network, server).
  Future<ExtractionResult> extractReceiptData(Uint8List imageBytes);
}
