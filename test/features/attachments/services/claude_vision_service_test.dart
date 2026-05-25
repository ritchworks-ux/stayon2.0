import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:stayon/features/attachments/services/claude_vision_service.dart';
import 'package:stayon/features/attachments/services/ocr_service.dart';

// Mock HTTP client
class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  group('ClaudeVisionService', () {
    late MockHttpClient mockHttpClient;
    late ClaudeVisionService service;
    late Uint8List validImageBytes;

    setUpAll(() {
      registerFallbackValue(FakeUri());
    });

    setUp(() {
      mockHttpClient = MockHttpClient();
      service = ClaudeVisionService(
        httpClient: mockHttpClient,
        apiKey: 'test-api-key',
      );
      // Valid test image (small JPEG)
      validImageBytes = Uint8List.fromList(
        List<int>.filled(5000, 0xFF), // ~5KB, valid JPEG-like bytes
      );
    });

    group('extractReceiptData', () {
      test('successfully extracts date and amount', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.type, 'receipt');
        expect(result.data['date'], '2026-05-24');
        expect(result.data['amount_cents'], 4599);
        expect(result.confidence, 0.95);
        expect(result.warnings, isEmpty);
      });

      test('handles missing date in response', () async {
        // Arrange
        const responseJson = '''{
          "date": null,
          "amount_cents": 4599,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.data.containsKey('date'), false);
        expect(result.data['amount_cents'], 4599);
        expect(result.confidence, 0.95);
      });

      test('handles missing amount in response', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": null,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.data['date'], '2026-05-24');
        expect(result.data.containsKey('amount_cents'), false);
        expect(result.confidence, 0.95);
      });

      test('handles single warning in response', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": ["date unclear"]
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.warnings, contains('date unclear'));
        expect(result.confidence, 0.85);
      });

      test('handles multiple warnings in response', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": ["date unclear", "amount partially obscured"]
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.warnings.length, 2);
        expect(result.confidence, 0.75);
      });

      test('rejects empty image bytes', () async {
        // Arrange
        final emptyBytes = Uint8List(0);

        // Act & Assert
        expect(
          () => service.extractReceiptData(emptyBytes),
          throwsA(
            isA<OcrException>()
                .having((e) => e.code, 'code', 'invalid_request')
                .having((e) => e.message, 'message', contains('empty')),
          ),
        );
      });

      test('rejects oversized image bytes', () async {
        // Arrange
        final oversizedBytes = Uint8List(2 * 1024 * 1024); // 2 MB

        // Act & Assert
        expect(
          () => service.extractReceiptData(oversizedBytes),
          throwsA(
            isA<OcrException>()
                .having((e) => e.code, 'code', 'invalid_request')
                .having((e) => e.message, 'message', contains('exceeds max')),
          ),
        );
      });

      test('handles 401 Unauthorized (auth failure)', () async {
        // Arrange
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Unauthorized', 401));

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>()
                .having((e) => e.code, 'code', 'auth_failed')
                .having(
                  (e) => e.message,
                  'message',
                  contains('authentication failed'),
                ),
          ),
        );
      });

      test('retries on 429 Rate Limited (up to 3 attempts)', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        // First two calls return 429, third succeeds
        var callCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount <= 2) {
            return http.Response('Too Many Requests', 429);
          } else {
            return http.Response(apiResponse, 200);
          }
        });

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.data['date'], '2026-05-24');
        verify(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).called(3);
      });

      test('throws after 3 failed rate limit retries', () async {
        // Arrange
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Too Many Requests', 429));

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>()
                .having((e) => e.code, 'code', 'rate_limited')
                .having(
                  (e) => e.message,
                  'message',
                  contains('rate limit exceeded'),
                ),
          ),
        );

        verify(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).called(3);
      });

      test('retries on 500 Server Error (up to 3 attempts)', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        // First two calls return 500, third succeeds
        var callCount = 0;
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount <= 2) {
            return http.Response('Internal Server Error', 500);
          } else {
            return http.Response(apiResponse, 200);
          }
        });

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.data['date'], '2026-05-24');
        verify(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).called(3);
      });

      test('throws after 3 failed server error retries', () async {
        // Arrange
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Internal Server Error', 500));

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>().having((e) => e.code, 'code', 'server_error'),
          ),
        );

        verify(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).called(3);
      });

      test('handles 400 Bad Request (image format)', () async {
        // Arrange
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('Bad Request', 400));

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>()
                .having((e) => e.code, 'code', 'invalid_request')
                .having((e) => e.message, 'message', contains('400')),
          ),
        );
      });

      test('handles request timeout', () async {
        // Arrange
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) => Future.delayed(
            const Duration(seconds: 31),
            () => http.Response('OK', 200),
          ),
        );

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>()
                .having((e) => e.code, 'code', 'network_error')
                .having((e) => e.message, 'message', contains('timeout')),
          ),
        );
      });

      test('handles JSON parse error in API response', () async {
        // Arrange
        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('invalid json {', 200));

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>().having((e) => e.code, 'code', 'parse_failed'),
          ),
        );
      });

      test('handles missing content array in API response', () async {
        // Arrange
        const apiResponse = '{"content": null}';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>()
                .having((e) => e.code, 'code', 'parse_failed')
                .having((e) => e.message, 'message', contains('content')),
          ),
        );
      });

      test('handles missing text in content[0]', () async {
        // Arrange
        const apiResponse = '''{
          "content": [
            {"type": "text"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act & Assert
        expect(
          () => service.extractReceiptData(validImageBytes),
          throwsA(
            isA<OcrException>().having((e) => e.code, 'code', 'parse_failed'),
          ),
        );
      });

      test('handles invalid date format (non-YYYY-MM-DD)', () async {
        // Arrange
        const responseJson = '''{
          "date": "05-24-2026",
          "amount_cents": 4599,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.data.containsKey('date'), false);
        expect(result.warnings, contains('date format invalid'));
      });

      test('handles invalid amount (negative)', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": -4599,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.data.containsKey('amount_cents'), false);
        expect(result.warnings, contains('amount is negative'));
      });

      test('converts double amount_cents to int', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599.7,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.data['amount_cents'], 4599);
      });

      test('confidence is 0.95 with no warnings', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": []
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.confidence, 0.95);
      });

      test('confidence is 0.85 with one warning', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": ["blurry"]
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.confidence, 0.85);
      });

      test('confidence is 0.75 with two+ warnings', () async {
        // Arrange
        const responseJson = '''{
          "date": "2026-05-24",
          "amount_cents": 4599,
          "warnings": ["blurry", "partially cut off"]
        }''';

        const apiResponse =
            '''{
          "content": [
            {"type": "text", "text": "$responseJson"}
          ]
        }''';

        when(
          () => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response(apiResponse, 200));

        // Act
        final result = await service.extractReceiptData(validImageBytes);

        // Assert
        expect(result.confidence, 0.75);
      });
    });
  });
}
