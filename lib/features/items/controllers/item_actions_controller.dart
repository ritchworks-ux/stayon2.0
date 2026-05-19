import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import '../data/item_repository.dart';
import 'item_providers.dart';

/// In-flight state for archive / trash / restore actions on a single
/// item from the Item Detail screen.
///
/// Each successful action invalidates both `itemsProvider` (so Home
/// re-fetches and the row disappears/reappears in its bucket) and
/// `itemByIdProvider(id)` (so any open Item Detail re-fetches and
/// shows the new status).
final itemActionsControllerProvider =
    AsyncNotifierProvider<ItemActionsController, void>(
      ItemActionsController.new,
    );

class ItemActionsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  ItemRepository get _repo => ref.read(itemRepositoryProvider);

  Future<Item?> _run(Future<Item> Function() op, String id) async {
    state = const AsyncValue.loading();
    Item? result;
    state = await AsyncValue.guard(() async {
      result = await op();
      ref.invalidate(itemsProvider);
      ref.invalidate(itemByIdProvider(id));
    });
    return state.hasError ? null : result;
  }

  /// Archive (status -> archived). Returns the updated item on success,
  /// `null` on failure (state.error holds the [ItemException]).
  Future<Item?> archive(String id) => _run(() => _repo.archive(id), id);

  /// Soft-delete (status -> trashed + trashed_at). Returns updated item.
  Future<Item?> trash(String id) => _run(() => _repo.trash(id), id);

  /// Restore from archive or trash (status -> active + trashed_at null).
  Future<Item?> restore(String id) => _run(() => _repo.restore(id), id);

  /// Reset to idle (used after a snackbar dismisses).
  void clear() {
    state = const AsyncValue.data(null);
  }
}
