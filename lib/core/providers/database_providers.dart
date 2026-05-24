import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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
