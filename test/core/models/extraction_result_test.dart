import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/extraction_result.dart';

void main() {
  test('round-trips barcode extraction result via JSON', () {
    final result = ExtractionResult(
      type: 'barcode',
      data: {
        'code': '123456789012',
        'format': 'EAN-13',
        'product_name': 'Coca-Cola',
      },
      confidence: 0.99,
      warnings: [],
    );
    expect(ExtractionResult.fromJson(result.toJson()), result);
  });

  test('round-trips receipt extraction result with warnings', () {
    final result = ExtractionResult(
      type: 'receipt',
      data: {
        'vendor': 'SM City',
        'total': '5,250.00',
        'items': ['Item 1', 'Item 2'],
      },
      confidence: 0.87,
      warnings: ['Low image quality', 'Partial date detected'],
    );
    expect(ExtractionResult.fromJson(result.toJson()), result);
  });

  test('validates confidence is between 0.0 and 1.0', () {
    final validResult = ExtractionResult(
      type: 'barcode',
      data: {'code': '123'},
      confidence: 0.5,
      warnings: [],
    );
    expect(validResult.confidence, 0.5);
  });

  test('allows empty warnings list', () {
    final result = ExtractionResult(
      type: 'barcode',
      data: {'code': '123'},
      confidence: 0.95,
      warnings: [],
    );
    expect(result.warnings, isEmpty);
  });

  test('decodes from untyped JSON', () {
    final json = {
      'type': 'barcode',
      'data': {'code': '7501234567890'},
      'confidence': 0.96,
      'warnings': null,
    };
    final result = ExtractionResult.fromJson(json);
    expect(result.type, 'barcode');
    expect(result.confidence, 0.96);
    expect(result.warnings, isEmpty);
  });
}
