import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stayon/features/attachments/services/open_food_facts_service.dart';
import 'package:stayon/core/providers/database_providers.dart';

/// Provides the [OpenFoodFactsService] singleton.
///
/// This service handles barcode lookups with caching and retry logic.
/// The service is initialized with the real CachedProductDao from the database provider.
/// Override in tests with a mock implementation.
final openFoodFactsServiceProvider = FutureProvider<OpenFoodFactsService>((ref) async {
  final cachedProductDao = await ref.watch(cachedProductDaoProvider.future);
  return OpenFoodFactsService(cachedProductDao: cachedProductDao);
});
