import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/storage_quota.dart';
import '../../../core/providers/database_providers.dart';
import '../data/attachment_repository.dart';

/// Provides the storage quota for the current user.
///
/// Useful for displaying quota usage in settings or during uploads.
/// Automatically refreshes when dependencies change.
///
/// Returns [StorageQuota] with usage metrics and tier information.
/// Throws [AttachmentException] if not signed in or if quota fetch fails.
final storageQuotaProvider = FutureProvider.autoDispose<StorageQuota>((ref) async {
  final repo = ref.watch(attachmentRepositoryProvider);
  return repo.getStorageQuota();
});
