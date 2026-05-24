import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/services/supabase_service.dart';
import 'core/providers/database_providers.dart';
import 'features/settings/controllers/theme_mode_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();

  // Initialize the database on startup
  final container = ProviderContainer();
  final db = await container.read(appDatabaseProvider.future);

  // Run cleanup of stale cached products on startup
  await db.cachedProductDao.cleanupStaleProducts();

  runApp(const ProviderScope(child: StayOnApp()));
}

class StayOnApp extends ConsumerWidget {
  const StayOnApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'StayOn',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
