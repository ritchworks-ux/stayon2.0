import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../features/attachments/data/attachment_repository.dart';
import '../../features/attachments/data/supabase_attachment_repository.dart';
import '../database/app_database.dart';

/// Provides the [AppDatabase] singleton instance.
///
/// Initialize and close the database connection. This provider is used
/// by all DAO and service providers that need database access.
final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/app_database.db');
  return AppDatabase(NativeDatabase(file));
});

/// Provides the [CachedProductDao] for barcode caching operations.
final cachedProductDaoProvider = FutureProvider((ref) async {
  final db = await ref.watch(appDatabaseProvider.future);
  return db.cachedProductDao;
});

/// Provides the [AttachmentRepository] for managing file attachments.
///
/// Production implementation uses Supabase for metadata and RLS enforcement.
/// Override in tests with a mock implementation.
final attachmentRepositoryProvider = Provider<AttachmentRepository>(
  (ref) => SupabaseAttachmentRepository(),
);
