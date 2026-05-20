import 'package:freezed_annotation/freezed_annotation.dart';

import 'item_category.dart';
import 'item_date_type.dart';
import 'item_status.dart';

part 'item.freezed.dart';
part 'item.g.dart';

@freezed
class Item with _$Item {
  const factory Item({
    required String id,
    @JsonKey(name: 'owner_id') required String ownerId,
    required String name,
    @JsonKey(fromJson: _catFromJson, toJson: _catToJson)
    required ItemCategory category,
    @JsonKey(name: 'date_type', fromJson: _dtFromJson, toJson: _dtToJson)
    required ItemDateType dateType,
    @JsonKey(name: 'target_date', fromJson: _dateFromJson, toJson: _dateToJson)
    required DateTime targetDate,
    String? notes,
    @JsonKey(name: 'assignee_label') String? assigneeLabel,
    @JsonKey(name: 'amount_minor') int? amountMinor,
    @JsonKey(name: 'currency_code') @Default('PHP') String currencyCode,
    @JsonKey(fromJson: _statusFromJson, toJson: _statusToJson)
    @Default(ItemStatus.active)
    ItemStatus status,
    @JsonKey(name: 'trashed_at') DateTime? trashedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Item;

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);
}

ItemCategory _catFromJson(String v) => ItemCategory.fromDb(v);
String _catToJson(ItemCategory c) => c.dbValue;
ItemDateType _dtFromJson(String v) => ItemDateType.fromDb(v);
String _dtToJson(ItemDateType d) => d.dbValue;
ItemStatus _statusFromJson(String v) => ItemStatus.fromDb(v);
String _statusToJson(ItemStatus s) => s.dbValue;

/// Postgres `date` round-trip. Parsed as UTC midnight so equality with
/// `DateTime.utc(y, m, d)` holds in tests and date math.
DateTime _dateFromJson(String v) {
  final parts = v.split('-');
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// Serialize a calendar date by its FACE-VALUE year/month/day. Must NOT
/// convert to UTC: a target_date has no timezone, and the date picker
/// returns a local-midnight DateTime. `.toUtc()` on local midnight in a
/// positive-offset zone (e.g. PH UTC+8) rolls the date back one day,
/// saving the wrong date. Using the DateTime's own fields is correct
/// whether it came from the picker (local) or from [_dateFromJson] (UTC).
String _dateToJson(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
