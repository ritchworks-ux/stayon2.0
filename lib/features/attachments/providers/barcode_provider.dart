import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayon/features/attachments/services/open_food_facts_service.dart';

/// Provides the [OpenFoodFactsService] singleton.
///
/// This service handles barcode lookups with caching and retry logic.
/// Override in tests with a mock implementation.
final openFoodFactsServiceProvider = Provider<OpenFoodFactsService>(
  (ref) => throw UnimplementedError(
    'openFoodFactsServiceProvider must be overridden in tests or main',
  ),
);
