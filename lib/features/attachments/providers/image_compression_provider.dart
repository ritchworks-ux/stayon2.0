import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayon/features/attachments/services/image_compression_service.dart';

/// Provides the [ImageCompressionService] singleton.
///
/// This service handles image compression with quality degradation and size targets.
/// Configuration:
/// - Target size: 1 MB
/// - Initial quality: 85%
/// - Minimum quality: 60%
/// - Format: JPEG only
///
/// Usage:
/// ```dart
/// final service = await ref.watch(imageCompressionServiceProvider.future);
/// final compressedBytes = await service.compressImage(imageFile);
/// ```
final imageCompressionServiceProvider = Provider<ImageCompressionService>((
  ref,
) {
  return ImageCompressionService(
    targetSizeBytes: 1024 * 1024, // 1 MB
    initialQuality: 85,
    minQuality: 60,
  );
});
