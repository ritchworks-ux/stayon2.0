import 'package:flutter_test/flutter_test.dart';
import 'package:stayon/core/models/storage_quota.dart';

void main() {
  test('round-trips via JSON with all fields', () {
    final quota = StorageQuota(
      ownerUserId: 'user-1',
      tier: 'free',
      totalBytesUsed: 10485760, // 10 MB
      quotaLimitBytes: 52428800, // 50 MB
      attachmentCount: 5,
      attachmentLimit: 10,
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    expect(StorageQuota.fromJson(quota.toJson()), quota);
  });

  test('round-trips premium tier quota', () {
    final quota = StorageQuota(
      ownerUserId: 'user-2',
      tier: 'premium',
      totalBytesUsed: 524288000, // 500 MB
      quotaLimitBytes: 1073741824, // 1 GB
      attachmentCount: 25,
      attachmentLimit: 100,
      updatedAt: DateTime.utc(2026, 5, 23),
    );
    expect(StorageQuota.fromJson(quota.toJson()), quota);
  });

  test('usagePercent computes correctly', () {
    final quota = StorageQuota(
      ownerUserId: 'user-1',
      tier: 'free',
      totalBytesUsed: 26214400, // 25 MB
      quotaLimitBytes: 52428800, // 50 MB
      attachmentCount: 5,
      attachmentLimit: 10,
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    expect(quota.usagePercent, 50);
  });

  test('usagePercent rounds to nearest integer', () {
    final quota = StorageQuota(
      ownerUserId: 'user-1',
      tier: 'free',
      totalBytesUsed: 31457280, // 30 MB
      quotaLimitBytes: 52428800, // 50 MB
      attachmentCount: 3,
      attachmentLimit: 10,
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    // 30/50 = 0.6 = 60%
    expect(quota.usagePercent, 60);
  });

  test('isAtCapacity returns true when at or above limit', () {
    final atCapacity = StorageQuota(
      ownerUserId: 'user-1',
      tier: 'free',
      totalBytesUsed: 52428800, // 50 MB
      quotaLimitBytes: 52428800, // 50 MB
      attachmentCount: 10,
      attachmentLimit: 10,
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    expect(atCapacity.isAtCapacity, true);
  });

  test('isAtCapacity returns false below limit', () {
    final notAtCapacity = StorageQuota(
      ownerUserId: 'user-1',
      tier: 'free',
      totalBytesUsed: 52000000,
      quotaLimitBytes: 52428800,
      attachmentCount: 9,
      attachmentLimit: 10,
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    expect(notAtCapacity.isAtCapacity, false);
  });

  test('nearCapacity returns true above 80%', () {
    final near = StorageQuota(
      ownerUserId: 'user-1',
      tier: 'free',
      totalBytesUsed: 41943040, // 40 MB = 80% of 50 MB
      quotaLimitBytes: 52428800,
      attachmentCount: 8,
      attachmentLimit: 10,
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    expect(near.nearCapacity, true);
  });

  test('nearCapacity returns false below 80%', () {
    final notNear = StorageQuota(
      ownerUserId: 'user-1',
      tier: 'free',
      totalBytesUsed: 41628467, // ~79.4%, rounds to 79%
      quotaLimitBytes: 52428800,
      attachmentCount: 7,
      attachmentLimit: 10,
      updatedAt: DateTime.utc(2026, 5, 24),
    );
    expect(notNear.nearCapacity, false);
  });

  test('decodes Supabase row shape', () {
    final row = {
      'owner_id': 'user-1',
      'tier': 'free',
      'total_bytes_used': 10485760,
      'quota_limit_bytes': 52428800,
      'attachment_count': 5,
      'attachment_limit': 10,
      'updated_at': '2026-05-24T10:30:00Z',
    };
    final quota = StorageQuota.fromJson(row);
    expect(quota.ownerUserId, 'user-1');
    expect(quota.tier, 'free');
    expect(quota.totalBytesUsed, 10485760);
  });
}
