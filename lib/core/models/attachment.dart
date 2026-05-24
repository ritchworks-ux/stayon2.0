import 'package:freezed_annotation/freezed_annotation.dart';

part 'attachment.freezed.dart';
part 'attachment.g.dart';

@freezed
class Attachment with _$Attachment {
  const factory Attachment({
    required String id,
    @JsonKey(name: 'owner_id') required String ownerId,
    @JsonKey(name: 'item_id') required String itemId,
    required String filename,
    @JsonKey(name: 'content_type') required String contentType,
    @JsonKey(name: 'file_size_bytes') required int fileSizeBytes,
    @JsonKey(name: 'storage_path') required String storagePath,
    @JsonKey(name: 'storage_tier') required String storageTier,
    @JsonKey(name: 'extraction_type') String? extractionType,
    @JsonKey(name: 'extraction_data') Map<String, dynamic>? extractionData,
    @JsonKey(name: 'extraction_confidence') double? extractionConfidence,
    @JsonKey(
      name: 'extraction_reviewed_at',
      fromJson: _dateTimeFromJson,
      toJson: _dateTimeToJson,
    )
    DateTime? extractionReviewedAt,
    @JsonKey(
      name: 'created_at',
      fromJson: _dateTimeFromJsonRequired,
      toJson: _dateTimeToJsonRequired,
    )
    required DateTime createdAt,
    @JsonKey(
      name: 'updated_at',
      fromJson: _dateTimeFromJsonRequired,
      toJson: _dateTimeToJsonRequired,
    )
    required DateTime updatedAt,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
}

/// Parse ISO 8601 UTC timestamp from Supabase (required fields).
DateTime _dateTimeFromJsonRequired(String v) {
  return DateTime.parse(v).toUtc();
}

/// Serialize DateTime to ISO 8601 UTC string (required fields).
String _dateTimeToJsonRequired(DateTime d) {
  return d.toUtc().toIso8601String();
}

/// Parse ISO 8601 UTC timestamp from Supabase (nullable fields).
DateTime? _dateTimeFromJson(String? v) {
  if (v == null) return null;
  return DateTime.parse(v).toUtc();
}

/// Serialize DateTime to ISO 8601 UTC string (nullable fields).
String? _dateTimeToJson(DateTime? d) {
  if (d == null) return null;
  return d.toUtc().toIso8601String();
}
