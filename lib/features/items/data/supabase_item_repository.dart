import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/item.dart';
import '../../../core/models/item_category.dart';
import '../../../core/models/item_date_type.dart';
import '../../../core/services/supabase_service.dart';
import 'item_repository.dart';
import 'items_data_source.dart';

/// Supabase-backed [ItemRepository]. All ownership is enforced by RLS
/// on the server; this class is responsible for setting `owner_id` at
/// insert time and mapping Postgres errors to friendly exceptions.
class SupabaseItemRepository implements ItemRepository {
  SupabaseItemRepository({
    sb.SupabaseClient? client,
    ItemsDataSource? dataSource,
    DateTime Function()? now,
  }) : _client = client ?? SupabaseService.client,
       _ds =
           dataSource ??
           SupabaseItemsDataSource(client ?? SupabaseService.client),
       _now = now ?? DateTime.now;

  final sb.SupabaseClient _client;
  final ItemsDataSource _ds;
  final DateTime Function() _now;

  /// The current authenticated user's id. Throws [ItemException] if
  /// no user is signed in (caller should never have gotten here).
  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw ItemException('not_signed_in', 'You must be signed in');
    }
    return id;
  }

  @override
  Future<List<Item>> fetchActive() async {
    try {
      final rows = await _ds.selectActive(_uid);
      return rows.map(Item.fromJson).toList();
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'fetch_failed');
    }
  }

  @override
  Future<Item> getById(String id) async {
    try {
      final row = await _ds.selectById(id);
      if (row == null) {
        throw ItemException('not_found', 'Item not found');
      }
      return Item.fromJson(row);
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'get_failed');
    }
  }

  @override
  Future<Item> add({
    required String name,
    required ItemCategory category,
    required ItemDateType dateType,
    required DateTime targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  }) async {
    final payload = <String, dynamic>{
      'owner_id': _uid,
      'name': name,
      'category': category.dbValue,
      'date_type': dateType.dbValue,
      'target_date': _dateOnly(targetDate),
      'notes': ?notes,
      'assignee_label': ?assigneeLabel,
      'amount_minor': ?amountMinor,
    };
    try {
      final row = await _ds.insert(payload);
      return Item.fromJson(row);
    } on sb.PostgrestException catch (e) {
      throw _map(e, 'add_failed');
    }
  }

  @override
  Future<Item> update(
    String id, {
    String? name,
    ItemCategory? category,
    ItemDateType? dateType,
    DateTime? targetDate,
    String? notes,
    String? assigneeLabel,
    int? amountMinor,
  }) async {
    final patch = <String, dynamic>{
      'name': ?name,
      if (category != null) 'category': category.dbValue,
      if (dateType != null) 'date_type': dateType.dbValue,
      if (targetDate != null) 'target_date': _dateOnly(targetDate),
      'notes': ?notes,
      'assignee_label': ?assigneeLabel,
      'amount_minor': ?amountMinor,
    };
    return _patch(id, patch, 'update_failed');
  }

  @override
  Future<Item> archive(String id) =>
      _patch(id, {'status': 'archived'}, 'archive_failed');

  @override
  Future<Item> trash(String id) => _patch(id, {
    'status': 'trashed',
    'trashed_at': _now().toUtc().toIso8601String(),
  }, 'trash_failed');

  @override
  Future<Item> restore(String id) =>
      _patch(id, {'status': 'active', 'trashed_at': null}, 'restore_failed');

  Future<Item> _patch(
    String id,
    Map<String, dynamic> patch,
    String fallbackCode,
  ) async {
    try {
      final row = await _ds.updateById(id, patch);
      return Item.fromJson(row);
    } on sb.PostgrestException catch (e) {
      throw _map(e, fallbackCode);
    }
  }

  /// Translates raw Postgres / PostgREST errors into [ItemException].
  /// 42501 is the RLS-violation code; we surface it as `rls` so the UI
  /// can show "You don't have access to this item" rather than the
  /// raw Postgres message.
  ItemException _map(sb.PostgrestException e, String fallback) {
    if (e.code == '42501') {
      return ItemException('rls', 'You do not have access to this item');
    }
    return ItemException(e.code ?? fallback, e.message);
  }

  /// Render `DateTime` as `YYYY-MM-DD` for Postgres `date` columns,
  /// in UTC to match the model's date semantics.
  String _dateOnly(DateTime d) {
    final u = d.toUtc();
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }
}
