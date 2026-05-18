import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:stayon/core/models/app_user.dart';
import 'package:stayon/features/auth/controllers/auth_controller.dart';
import 'package:stayon/features/auth/controllers/auth_providers.dart';
import 'package:stayon/features/auth/data/auth_repository.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockAuthRepository repo;

  setUp(() {
    repo = _MockAuthRepository();
    when(
      () => repo.currentUserChanges(),
    ).thenAnswer((_) => Stream<AppUser?>.value(null));
    when(() => repo.currentUser).thenReturn(null);
  });

  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
  );

  test('signInWithEmail delegates to repository', () async {
    when(
      () => repo.signInWithEmail(email: 'a@b.co', password: 'secret123'),
    ).thenAnswer((_) async {});

    final c = makeContainer();
    addTearDown(c.dispose);

    await c
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.co', password: 'secret123');

    verify(
      () => repo.signInWithEmail(email: 'a@b.co', password: 'secret123'),
    ).called(1);
    expect(c.read(authControllerProvider).hasError, isFalse);
  });

  test('signInWithEmail surfaces AuthException as error state', () async {
    when(
      () => repo.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(AuthException('invalid_credentials', 'Bad creds'));

    final c = makeContainer();
    addTearDown(c.dispose);

    await c
        .read(authControllerProvider.notifier)
        .signIn(email: 'a@b.co', password: 'wrong');

    final state = c.read(authControllerProvider);
    expect(state.hasError, isTrue);
    expect(state.error, isA<AuthException>());
  });

  test('signOut delegates to repository', () async {
    when(() => repo.signOut()).thenAnswer((_) async {});

    final c = makeContainer();
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).signOut();

    verify(() => repo.signOut()).called(1);
  });
}
