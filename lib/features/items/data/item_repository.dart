import '../../../core/models/item.dart';
import '../../../core/models/item_category.dart';
import '../../../core/models/item_date_type.dart';

/// Repository contract for item persistence.
///
/// V1 (Phase 2) ships a Supabase implementation only. The interface is
/// intentionally Future-based so the implementation can stay simple
/// (no realtime); Phase 2b adds a parallel `watchActive()` stream
/// without breaking callers.
abstract interface class ItemRepository {
  /// Returns the current user's active items sorted by target_date asc.
  /// Throws [ItemException] on failure.
  Future<List<Item>> fetchActive();

  /// Single item by id, regardless of status. Throws [ItemException] if
  /// not found or RLS denies the read.
  Future<Item> getById(String id);

  /// Creates a new item owned by the current user.
  /// Throws [ItemException] on failure (including RLS denial).
  Future<Item> add({
    required String name,
    required ItemCategory category,
    required ItemDateType dateType,
    required DateTime targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  });

  /// Updates the named fields on an item the caller owns. Any field left
  /// null is left untouched (it is NOT cleared). To clear a nullable
  /// field, send a sentinel (not supported in V1; we don't need it yet).
  /// Throws [ItemException] on failure.
  Future<Item> update(
    String id, {
    String? name,
    ItemCategory? category,
    ItemDateType? dateType,
    DateTime? targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  });

  /// Soft-state transitions used by the action row.
  Future<Item> archive(String id);
  Future<Item> trash(String id);
  Future<Item> restore(String id);
}

/// Thrown by [ItemRepository] for any user-actionable failure.
/// UI maps [code] to a friendly message.
class ItemException implements Exception {
  ItemException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'ItemException($code): $message';
}
