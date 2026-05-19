import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/app/router/app_router.dart';
import 'package:stayon/core/models/app_user.dart';
import 'package:stayon/features/auth/controllers/auth_providers.dart';
import 'package:stayon/features/auth/data/auth_repository.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;
  setUp(() => repo = _MockRepo());

  ProviderContainer makeContainer({AppUser? user}) {
    when(() => repo.currentUser).thenReturn(user);
    when(
      () => repo.currentUserChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(user));
    return ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
  }

  /// Container that exposes a [controller] you can push values into to
  /// simulate auth state transitions (sign-in / sign-out) mid-test.
  ({ProviderContainer container, StreamController<AppUser?> controller})
  makeLiveContainer({AppUser? initial}) {
    final controller = StreamController<AppUser?>.broadcast();
    when(() => repo.currentUser).thenReturn(initial);
    when(() => repo.currentUserChanges()).thenAnswer((_) async* {
      yield initial;
      yield* controller.stream;
    });
    return (
      container: ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      ),
      controller: controller,
    );
  }

  testWidgets('unauthenticated user is redirected to /auth/sign-in', (
    tester,
  ) async {
    final c = makeContainer(user: null);
    addTearDown(c.dispose);

    final router = c.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/auth/sign-in',
    );
  });

  testWidgets('authenticated user landing on /auth is redirected to /home', (
    tester,
  ) async {
    const user = AppUser(id: 'u1', email: 'a@b.co');
    final c = makeContainer(user: user);
    addTearDown(c.dispose);

    final router = c.read(appRouterProvider);
    router.go('/auth/sign-in');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
  });

  testWidgets(
    'unauthenticated user navigating to /item/:id is redirected to sign-in',
    (tester) async {
      final c = makeContainer(user: null);
      addTearDown(c.dispose);

      final router = c.read(appRouterProvider);
      router.go('/item/abc-123');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        router.routerDelegate.currentConfiguration.uri.path,
        '/auth/sign-in',
      );
    },
  );

  testWidgets('redirects /home -> /auth/sign-in when auth stream emits null '
      '(sign-out regression)', (tester) async {
    const user = AppUser(id: 'u1', email: 'a@b.co');
    final live = makeLiveContainer(initial: user);
    addTearDown(live.container.dispose);
    addTearDown(live.controller.close);

    final router = live.container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: live.container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');

    // Update the mock so the redirect's ref.read sees the new state.
    when(() => repo.currentUser).thenReturn(null);
    // Simulate Supabase emitting the signed-out event.
    live.controller.add(null);
    await tester.pumpAndSettle();

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/auth/sign-in',
    );
  });
}
