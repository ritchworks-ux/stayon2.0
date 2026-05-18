import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/app/router/app_router.dart';
import 'package:stayon/app/theme/app_theme.dart';
import 'package:stayon/core/models/app_user.dart';
import 'package:stayon/features/auth/controllers/auth_providers.dart';
import 'package:stayon/features/auth/data/auth_repository.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  testWidgets('App boots to sign-in when signed out', (tester) async {
    final repo = _MockRepo();
    when(() => repo.currentUser).thenReturn(null);
    when(
      () => repo.currentUserChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(appRouterProvider);
            return MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
  });
}
