import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/app_user.dart';
import 'package:stayon/features/auth/controllers/auth_providers.dart';
import 'package:stayon/features/auth/data/auth_repository.dart';
import 'package:stayon/features/auth/ui/sign_in_screen.dart';

class _MockRepo extends Mock implements AuthRepository {}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    when(
      () => repo.currentUserChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(null));
    when(() => repo.currentUser).thenReturn(null);
  });

  Widget wrap() => ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(
      // NoSplash avoids the ink_sparkle.frag shader version mismatch
      // that causes spurious failures when tester.tap() triggers InkWell.
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      home: const SignInScreen(),
    ),
  );

  testWidgets('shows email + password fields and a Sign in button', (
    tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('blocks submit when email is empty', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Email is required'), findsOneWidget);
    verifyNever(
      () => repo.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  testWidgets('calls repository on valid submit', (tester) async {
    when(
      () => repo.signInWithEmail(email: 'a@b.co', password: 'secret123'),
    ).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    verify(
      () => repo.signInWithEmail(email: 'a@b.co', password: 'secret123'),
    ).called(1);
  });
}
