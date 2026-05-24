import 'package:freezed_annotation/freezed_annotation.dart';

part 'storage_quota.freezed.dart';
part 'storage_quota.g.dart';

@freezed
class StorageQuota with _$StorageQuota {
  const factory StorageQuota({
    @JsonKey(name: 'owner_id') required String ownerUserId,
    required String tier,
    @JsonKey(name: 'total_bytes_used') required int totalBytesUsed,
    @JsonKey(name: 'quota_limit_bytes') required int quotaLimitBytes,
    @JsonKey(name: 'attachment_count') required int attachmentCount,
    @JsonKey(name: 'attachment_limit') required int attachmentLimit,
    @JsonKey(
      name: 'updated_at',
      fromJson: _dateTimeFromJsonRequired,
      toJson: _dateTimeToJsonRequired,
    )
    required DateTime updatedAt,
  }) = _StorageQuota;

  const StorageQuota._();

  factory StorageQuota.fromJson(Map<String, dynamic> json) =>
      _$StorageQuotaFromJson(json);

  /// Usage as a percentage (0–100), rounded to nearest integer.
  int get usagePercent {
    if (quotaLimitBytes == 0) return 0;
    return ((totalBytesUsed / quotaLimitBytes) * 100).round();
  }

  /// True if at or over capacity.
  bool get isAtCapacity => totalBytesUsed >= quotaLimitBytes;

  /// True if usage is 80% or above.
  bool get nearCapacity => usagePercent >= 80;
}

/// Parse ISO 8601 UTC timestamp from Supabase.
DateTime _dateTimeFromJsonRequired(String v) {
  return DateTime.parse(v).toUtc();
}

/// Serialize DateTime to ISO 8601 UTC string.
String _dateTimeToJsonRequired(DateTime d) {
  return d.toUtc().toIso8601String();
}
