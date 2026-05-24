import 'package:freezed_annotation/freezed_annotation.dart';

part 'extraction_result.freezed.dart';
part 'extraction_result.g.dart';

/// Result of extraction (barcode scanning or OCR).
///
/// - `type`: 'barcode' or 'receipt'
/// - `data`: Untyped extraction fields (vendor, total, code, etc.)
/// - `confidence`: 0.0–1.0 confidence score
/// - `warnings`: List of non-fatal issues (e.g., "Low image quality")
@freezed
class ExtractionResult with _$ExtractionResult {
  const factory ExtractionResult({
    required String type,
    required Map<String, dynamic> data,
    required double confidence,
    @Default([]) List<String> warnings,
  }) = _ExtractionResult;

  factory ExtractionResult.fromJson(Map<String, dynamic> json) =>
      _$ExtractionResultFromJson(json);
}
