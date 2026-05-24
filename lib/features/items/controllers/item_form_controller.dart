import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/item.dart';
import '../../../core/models/item_category.dart';
import '../../../core/models/item_date_type.dart';
import '../data/item_repository.dart';
import 'item_providers.dart';

/// In-flight state for Add Item / Edit Item modal submissions.
///
/// - `AsyncData(null)` — idle (initial state)
/// - `AsyncLoading()` — submit in flight
/// - `AsyncError(ItemException, _)` — last submit failed (UI shows snackbar)
///
/// Every successful submit also invalidates [itemsProvider] so Home
/// re-fetches on next watch.
final itemFormControllerProvider =
    AsyncNotifierProvider<ItemFormController, void>(ItemFormController.new);

class ItemFormController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  ItemRepository get _repo => ref.read(itemRepositoryProvider);

  /// Add a new item owned by the current user.
  /// `owner_id` is set by the repository from `auth.uid()` — UI cannot
  /// override it. Invalidates [itemsProvider] on success.
  Future<void> submitNew({
    required String name,
    required ItemCategory category,
    required ItemDateType dateType,
    required DateTime targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.add(
        name: name,
        category: category,
        dateType: dateType,
        targetDate: targetDate,
        notes: notes,
        assigneeLabel: assigneeLabel,
        amountMinor: amountMinor,
      );
      ref.invalidate(itemsProvider);
    });
  }

  /// Add a new item and return the created item object.
  ///
  /// Same as [submitNew] but returns the created Item instead of void.
  /// Useful when the caller needs the item ID to create related records
  /// (e.g., attachments).
  ///
  /// Throws [ItemException] on failure.
  Future<Item> submitNewAndReturnItem({
    required String name,
    required ItemCategory category,
    required ItemDateType dateType,
    required DateTime targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  }) async {
    state = const AsyncValue.loading();
    try {
      final item = await _repo.add(
        name: name,
        category: category,
        dateType: dateType,
        targetDate: targetDate,
        notes: notes,
        assigneeLabel: assigneeLabel,
        amountMinor: amountMinor,
      );
      ref.invalidate(itemsProvider);
      state = const AsyncValue.data(null);
      return item;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  /// Patch an existing item. Only non-null fields are sent. On success
  /// invalidates BOTH [itemsProvider] (so Home re-fetches and re-buckets
  /// if target_date changed) AND [itemByIdProvider] for this id (so the
  /// Item Detail screen the user just edited from shows fresh values
  /// instead of its cached pre-edit copy).
  Future<void> submitEdit(
    String id, {
    String? name,
    ItemCategory? category,
    ItemDateType? dateType,
    DateTime? targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.update(
        id,
        name: name,
        category: category,
        dateType: dateType,
        targetDate: targetDate,
        notes: notes,
        assigneeLabel: assigneeLabel,
        amountMinor: amountMinor,
      );
      ref.invalidate(itemsProvider);
      ref.invalidate(itemByIdProvider(id));
    });
  }

  /// Clear an error state without re-submitting (e.g. after the user
  /// dismisses the snackbar and edits the form).
  void clearError() {
    state = const AsyncValue.data(null);
  }
}
