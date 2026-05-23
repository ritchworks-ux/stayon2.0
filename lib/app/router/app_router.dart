import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/app_user.dart';
import '../../features/alerts/ui/alerts_screen.dart';
import '../../features/auth/controllers/auth_providers.dart';
import '../../features/auth/ui/sign_in_screen.dart';
import '../../features/auth/ui/sign_up_screen.dart';
import '../../features/calendar/ui/calendar_screen.dart';
import '../../features/family/ui/family_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../../features/items/ui/item_detail_screen.dart';
import '../../features/settings/ui/settings_screen.dart';
import '../shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    debugLogDiagnostics: false,
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      // Read authStateProvider directly, not the derived currentUserProvider.
      // currentUserProvider is a non-disposing Provider that caches its
      // computed value; when authStateProvider's stream emits a new value
      // and `_AuthRefresh` synchronously re-triggers the redirect via
      // notifyListeners, the cached currentUserProvider may not yet have
      // recomputed, returning a stale user. authStateProvider's state is
      // updated synchronously when the underlying stream emits, so reading
      // it here is always current.
      final user = ref.read(authStateProvider).valueOrNull;
      final loggedIn = user != null;
      final goingToAuth = state.matchedLocation.startsWith('/auth');

      if (!loggedIn && !goingToAuth) return '/auth/sign-in';
      if (loggedIn && goingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/auth/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/auth/sign-up', builder: (_, _) => const SignUpScreen()),
      // Full-screen routes (no bottom nav). Auth-guarded by the redirect above.
      GoRoute(
        path: '/item/:id',
        builder: (_, state) =>
            ItemDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/calendar',
                builder: (_, _) => const CalendarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/alerts', builder: (_, _) => const AlertsScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/family', builder: (_, _) => const FamilyScreen()),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth changes into go_router's refresh mechanism.
///
/// The generic on `ref.listen` MUST be the provider's exact value type
/// (`AsyncValue<AppUser?>` here). A widened type like `AsyncValue<Object?>`
/// type-checks but Riverpod silently never fires the listener at runtime —
/// `notifyListeners` would never be called and `GoRouter` would never
/// re-evaluate its redirect after sign-in / sign-out.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Ref ref) {
    _sub = ref.listen<AsyncValue<AppUser?>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<AppUser?>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
