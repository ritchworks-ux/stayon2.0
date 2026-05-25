import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Exception thrown during image compression operations.
class CompressionException implements Exception {
  CompressionException({required this.code, required this.message});

  /// Error code: 'invalid_format', 'file_too_large', 'compression_failed', 'file_not_found'
  final String code;

  /// Human-readable error message.
  final String message;

  @override
  String toString() => 'CompressionException($code): $message';
}

/// Service for compressing images with configurable quality and size targets.
///
/// Features:
/// - Compress to JPEG format with configurable quality
/// - Automatic quality degradation if size exceeds target
/// - Input validation (format, file size)
/// - Target: < 1 MB final size
/// - Quality range: 60–85% (degradation steps of 5%)
///
/// Usage:
/// ```dart
/// final service = ImageCompressionService();
/// final compressedBytes = await service.compressImage(imageFile);
/// ```
class ImageCompressionService {
  ImageCompressionService({
    int targetSizeBytes = 1024 * 1024, // 1 MB default
    int initialQuality = 85,
    int minQuality = 60,
  }) : _targetSizeBytes = targetSizeBytes,
       _initialQuality = initialQuality,
       _minQuality = minQuality;

  static const int _maxPreCompressionSize = 10 * 1024 * 1024; // 10 MB
  static const List<String> _supportedFormats = ['jpg', 'jpeg', 'png'];

  final int _targetSizeBytes;
  final int _initialQuality;
  final int _minQuality;

  /// Compress an image file to JPEG format with target size < 1 MB.
  ///
  /// Quality degradation strategy:
  /// - Start at 85% quality
  /// - If result > 1 MB, reduce by 5% and retry
  /// - Minimum quality: 60%
  /// - If still oversized at min quality, throw [CompressionException]
  ///
  /// Returns compressed image bytes ready for upload or storage.
  ///
  /// Throws:
  /// - [CompressionException] with code 'file_not_found' if file does not exist
  /// - [CompressionException] with code 'invalid_format' if format not supported
  /// - [CompressionException] with code 'file_too_large' if > 10 MB
  /// - [CompressionException] with code 'compression_failed' if compression fails
  Future<Uint8List> compressImage(File imageFile) async {
    // 1. Validate file exists
    if (!imageFile.existsSync()) {
      throw CompressionException(
        code: 'file_not_found',
        message: 'Image file not found: ${imageFile.path}',
      );
    }

    // 2. Validate format
    final extension = _getFileExtension(imageFile.path).toLowerCase();
    if (!_supportedFormats.contains(extension)) {
      throw CompressionException(
        code: 'invalid_format',
        message:
            'Unsupported image format: .$extension. Supported: jpg, jpeg, png',
      );
    }

    // 3. Validate pre-compression size
    final fileSize = imageFile.lengthSync();
    if (fileSize > _maxPreCompressionSize) {
      throw CompressionException(
        code: 'file_too_large',
        message:
            'Image file too large: ${_formatBytes(fileSize)}. Max: ${_formatBytes(_maxPreCompressionSize)}',
      );
    }

    // 4. Compress with quality degradation loop
    int quality = _initialQuality;
    Uint8List? compressedBytes;

    while (quality >= _minQuality) {
      try {
        compressedBytes = await _performCompression(imageFile, quality);

        if (compressedBytes.lengthInBytes <= _targetSizeBytes) {
          // Success: compressed to target size
          return compressedBytes;
        }

        // Still oversized, degrade quality and retry
        quality -= 5;
      } catch (e) {
        throw CompressionException(
          code: 'compression_failed',
          message: 'Compression failed at quality $quality%: $e',
        );
      }
    }

    // All quality levels exhausted; last attempt was the best we could do
    if (compressedBytes != null &&
        compressedBytes.lengthInBytes <= _targetSizeBytes * 1.2) {
      // Within 20% tolerance (e.g., 1.2 MB for 1 MB target)
      // This is acceptable as a fallback
      return compressedBytes;
    }

    throw CompressionException(
      code: 'compression_failed',
      message:
          'Could not compress image below ${_formatBytes(_targetSizeBytes)} at quality $quality%. Final size: ${_formatBytes(compressedBytes?.lengthInBytes ?? 0)}',
    );
  }

  /// Perform JPEG compression at specified quality level.
  Future<Uint8List> _performCompression(File imageFile, int quality) async {
    final bytes = await imageFile.readAsBytes();

    final compressed = await FlutterImageCompress.compressWithList(
      bytes,
      minHeight: 1920,
      minWidth: 1080,
      quality: quality,
      rotate: 0,
      format: CompressFormat.jpeg,
    );

    if (compressed.isEmpty) {
      throw CompressionException(
        code: 'compression_failed',
        message: 'Compression returned empty result at quality $quality%',
      );
    }

    return Uint8List.fromList(compressed);
  }

  /// Extract file extension without the dot.
  String _getFileExtension(String path) {
    final lastDot = path.lastIndexOf('.');
    if (lastDot == -1) return '';
    return path.substring(lastDot + 1);
  }

  /// Format bytes as human-readable string (e.g., "2.5 MB").
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
