import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import '../data/item_repository.dart';
import '../data/supabase_item_repository.dart';

/// Production [ItemRepository] backed by Supabase.
/// Override in tests with a mock implementation.
final itemRepositoryProvider = Provider<ItemRepository>(
  (ref) => SupabaseItemRepository(),
);

/// Fetches the current user's active items, sorted by target_date asc.
///
/// **Refresh contract:** every mutation controller
/// (`itemFormControllerProvider`, `itemActionsControllerProvider`) calls
/// `ref.invalidate(itemsProvider)` after a successful write so the next
/// Home build re-fetches. UI does NOT call the repository directly.
///
/// Pull-to-refresh on Home calls `ref.refresh(itemsProvider.future)`.
final itemsProvider = FutureProvider<List<Item>>(
  (ref) => ref.watch(itemRepositoryProvider).fetchActive(),
);

/// Lookup a single item by id. Used by Item Detail.
final itemByIdProvider = FutureProvider.family<Item, String>((ref, id) async {
  return ref.watch(itemRepositoryProvider).getById(id);
});
