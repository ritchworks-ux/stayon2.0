import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/alerts/ui/alerts_screen.dart';
import '../../features/auth/controllers/auth_providers.dart';
import '../../features/auth/ui/sign_in_screen.dart';
import '../../features/auth/ui/sign_up_screen.dart';
import '../../features/calendar/ui/calendar_screen.dart';
import '../../features/family/ui/family_screen.dart';
import '../../features/home/ui/home_screen.dart';
import '../shell/app_shell.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home',
    debugLogDiagnostics: false,
    refreshListenable: _AuthRefresh(ref),
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final loggedIn = user != null;
      final goingToAuth = state.matchedLocation.startsWith('/auth');

      if (!loggedIn && !goingToAuth) return '/auth/sign-in';
      if (loggedIn && goingToAuth) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/auth/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/auth/sign-up', builder: (_, _) => const SignUpScreen()),
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
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _sub = _ref.listen<AsyncValue<AppUserOrNull>>(
      authStateProvider,
      (_, _) => notifyListeners(),
    );
  }
  final Ref _ref;
  late final ProviderSubscription<AsyncValue<AppUserOrNull>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}

/// Alias used only by [_AuthRefresh] to keep the listen signature explicit.
typedef AppUserOrNull = Object?;
