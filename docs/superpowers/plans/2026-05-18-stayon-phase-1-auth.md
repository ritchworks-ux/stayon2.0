# StayOn Phase 1 — Supabase + Email/Password Auth + App Shell

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up Supabase, ship working email/password sign-up + sign-in + sign-out with a bootstrapped `profiles` row, plus the 5-slot bottom-nav app shell with an empty hero-matched Home. End state: a real user can install the app, create an account, see their name on Home, sign out, sign back in.

**Architecture:** UI → Riverpod controller → Repository (interface) → Supabase service. Auth state is a `Stream<AuthState>` exposed by a Riverpod provider; `go_router` redirects based on it. Secrets injected via `--dart-define` at build time (Supabase URL + anon key — the anon key is safe to ship, RLS enforces all access). Sessions persisted by Supabase to `flutter_secure_storage`.

**Tech Stack:** `supabase_flutter` ^2.12 · `flutter_riverpod` ^2.5 · `go_router` ^14 · `freezed` ^2.5 · `mocktail` ^1 · `flutter_secure_storage` ^9.

**Source spec:** [`docs/superpowers/specs/2026-05-18-stayon-mvp-design.md`](../specs/2026-05-18-stayon-mvp-design.md)
**Master plan:** [`docs/superpowers/plans/2026-05-18-stayon-mvp.md`](2026-05-18-stayon-mvp.md)

**Explicitly out of scope for this phase:**
- Google + Apple sign-in (Phase 1b — needs external portal setup)
- Items / attachments / reminders / OCR (Phases 2–5)
- Real Calendar / Alerts / Family content (placeholder stubs only)
- Account deletion UI (Phase 6)

---

## A. File map

### Created
| Path | Responsibility |
|---|---|
| `lib/core/config/env.dart` | Read `--dart-define` values, fail loudly if missing |
| `lib/core/services/supabase_service.dart` | Init + global accessor for the `SupabaseClient` |
| `lib/core/models/app_user.dart` | Freezed `AppUser` value type |
| `lib/features/auth/data/auth_repository.dart` | Abstract repository interface |
| `lib/features/auth/data/supabase_auth_repository.dart` | Supabase implementation |
| `lib/features/auth/controllers/auth_controller.dart` | Riverpod `AsyncNotifier` for sign-in/up/out |
| `lib/features/auth/controllers/auth_providers.dart` | `authRepositoryProvider`, `authStateProvider`, `currentUserProvider` |
| `lib/features/auth/ui/sign_in_screen.dart` | Email + password sign-in form |
| `lib/features/auth/ui/sign_up_screen.dart` | Email + password sign-up form |
| `lib/features/auth/ui/auth_form_widgets.dart` | Shared text fields + submit button |
| `lib/app/router/app_router.dart` | `go_router` with auth guard + redirect |
| `lib/app/shell/app_shell.dart` | `StatefulShellRoute` bottom-nav scaffold |
| `lib/features/home/ui/home_screen.dart` | Empty hero-matched home (greeting + empty card) |
| `lib/features/calendar/ui/calendar_screen.dart` | Stub: "Calendar — coming in Phase 5" |
| `lib/features/alerts/ui/alerts_screen.dart` | Stub: "Alerts — coming in Phase 5" |
| `lib/features/family/ui/family_screen.dart` | Stub: "People & Shares — coming in Phase 6" |
| `test/features/auth/auth_controller_test.dart` | Controller tests with `mocktail` |
| `test/features/auth/sign_in_screen_test.dart` | Widget test for form validation + submit |
| `test/app/router/app_router_test.dart` | Redirect logic test |
| `integration_test/auth_flow_test.dart` | Sign-up → verify → sign-out (run manually) |

### Modified
| Path | Why |
|---|---|
| `lib/main.dart` | Init Supabase before `runApp`; switch from `home:` to `router:` |
| `lib/app/shell/placeholder_home.dart` | **Deleted** — replaced by `app_shell.dart` + `home_screen.dart` |
| `test/widget_test.dart` | Update to expect router-based root instead of placeholder |
| `README.md` | Add Supabase setup instructions + `--dart-define` example |

---

## B. Manual prerequisites (user does these once — block on completion)

### Task M1: Create the Supabase project

- [ ] **Step 1: Sign in / create account at https://supabase.com**

- [ ] **Step 2: Click "New project"**
  - Organization: your personal (free tier)
  - Project name: `stayon-prod` (we will create a second `stayon-dev` later if needed)
  - Database password: generate strong, save in a password manager
  - Region: **Southeast Asia (Singapore) — `ap-southeast-1`** (closest to PH)
  - Pricing plan: **Free**

- [ ] **Step 3: Wait ~2 min for provisioning, then go to Project Settings → API**
  - Copy **Project URL** (looks like `https://xxxx.supabase.co`)
  - Copy **anon public** key (long JWT string)
  - **Do NOT copy** the `service_role` key — never put that in the app

- [ ] **Step 4: Enable email auth**
  - Authentication → Providers → **Email**: leave enabled
  - Authentication → Providers → toggle **Confirm email** ON (we want verified emails before login)
  - Authentication → Email Templates → leave defaults for now

- [ ] **Step 5: Save the URL + anon key in a local `.env.local` file in the repo root (already gitignored)**

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

These values are referenced via `--dart-define-from-file=.env.local` in run/build commands.

---

## C. Code tasks

### Task 1: Wire env config

**Files:**
- Create: `lib/core/config/env.dart`
- Test: none (trivial reader)

- [ ] **Step 1: Write `lib/core/config/env.dart`**

```dart
/// Build-time configuration read from --dart-define values.
/// Missing values throw at startup so we never run with a misconfigured backend.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Throws [StateError] if any required value is empty.
  static void assertValid() {
    if (supabaseUrl.isEmpty) {
      throw StateError('SUPABASE_URL is not set. '
          'Run with --dart-define-from-file=.env.local');
    }
    if (supabaseAnonKey.isEmpty) {
      throw StateError('SUPABASE_ANON_KEY is not set. '
          'Run with --dart-define-from-file=.env.local');
    }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/config/env.dart
git commit -m "feat(config): add Env reader for --dart-define values"
```

---

### Task 2: SupabaseService

**Files:**
- Create: `lib/core/services/supabase_service.dart`

- [ ] **Step 1: Write `lib/core/services/supabase_service.dart`**

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Thin wrapper that owns Supabase initialization.
/// Call [SupabaseService.init] exactly once before runApp.
abstract final class SupabaseService {
  static Future<void> init() async {
    Env.assertValid();
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Global client. Safe to call from anywhere after [init].
  static SupabaseClient get client => Supabase.instance.client;
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/core/services/supabase_service.dart
git commit -m "feat(core): add SupabaseService initialization wrapper"
```

---

### Task 3: AppUser model

**Files:**
- Create: `lib/core/models/app_user.dart`
- Generated: `lib/core/models/app_user.freezed.dart`

- [ ] **Step 1: Write `lib/core/models/app_user.dart`**

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String email,
    String? displayName,
  }) = _AppUser;
}
```

- [ ] **Step 2: Run build_runner**

```bash
dart run build_runner build --delete-conflicting-outputs
```
Expected: `lib/core/models/app_user.freezed.dart` is generated.

- [ ] **Step 3: Verify analyze clean**

```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/core/models/app_user.dart lib/core/models/app_user.freezed.dart
git commit -m "feat(models): add AppUser freezed model"
```

---

### Task 4: AuthRepository interface

**Files:**
- Create: `lib/features/auth/data/auth_repository.dart`

- [ ] **Step 1: Write `lib/features/auth/data/auth_repository.dart`**

```dart
import '../../../core/models/app_user.dart';

/// Repository contract for authentication operations.
/// All async ops throw on failure (no Result wrapper — controllers translate).
abstract interface class AuthRepository {
  /// Emits the current user, or null after sign-out.
  /// Emits immediately with current cached value on subscribe.
  Stream<AppUser?> currentUserChanges();

  /// Synchronous read of the current user (may be null).
  AppUser? get currentUser;

  /// Throws [AuthException] on failure (e.g. duplicate email).
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Throws [AuthException] on failure (e.g. invalid credentials).
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

/// Thrown by [AuthRepository] for any user-actionable failure.
/// UI maps [code] to a friendly message.
class AuthException implements Exception {
  AuthException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => 'AuthException($code): $message';
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/data/auth_repository.dart
git commit -m "feat(auth): add AuthRepository contract"
```

---

### Task 5: SupabaseAuthRepository

**Files:**
- Create: `lib/features/auth/data/supabase_auth_repository.dart`

- [ ] **Step 1: Write `lib/features/auth/data/supabase_auth_repository.dart`**

```dart
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/app_user.dart';
import '../../../core/services/supabase_service.dart';
import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository({sb.SupabaseClient? client})
      : _client = client ?? SupabaseService.client;

  final sb.SupabaseClient _client;

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Stream<AppUser?> currentUserChanges() async* {
    yield currentUser;
    yield* _client.auth.onAuthStateChange.map(
      (event) => _toAppUser(event.session?.user),
    );
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signUp(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthException(e.code ?? 'sign_up_failed', e.message);
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on sb.AuthException catch (e) {
      throw AuthException(e.code ?? 'sign_in_failed', e.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  AppUser? _toAppUser(sb.User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: user.userMetadata?['display_name'] as String?,
    );
  }
}
```

- [ ] **Step 2: Verify analyze clean**

```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/data/supabase_auth_repository.dart
git commit -m "feat(auth): add Supabase implementation of AuthRepository"
```

---

### Task 6: Auth controller — failing tests first

**Files:**
- Create: `test/features/auth/auth_controller_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
import 'dart:async';

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
    when(() => repo.currentUserChanges())
        .thenAnswer((_) => Stream<AppUser?>.value(null));
    when(() => repo.currentUser).thenReturn(null);
  });

  ProviderContainer makeContainer() => ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
      );

  test('signInWithEmail delegates to repository', () async {
    when(() => repo.signInWithEmail(
          email: 'a@b.co',
          password: 'secret123',
        )).thenAnswer((_) async {});

    final c = makeContainer();
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).signIn(
          email: 'a@b.co',
          password: 'secret123',
        );

    verify(() => repo.signInWithEmail(
          email: 'a@b.co',
          password: 'secret123',
        )).called(1);
    expect(c.read(authControllerProvider).hasError, isFalse);
  });

  test('signInWithEmail surfaces AuthException as error state', () async {
    when(() => repo.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        )).thenThrow(AuthException('invalid_credentials', 'Bad creds'));

    final c = makeContainer();
    addTearDown(c.dispose);

    await c.read(authControllerProvider.notifier).signIn(
          email: 'a@b.co',
          password: 'wrong',
        );

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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
flutter test test/features/auth/auth_controller_test.dart
```
Expected: failures referencing missing `authControllerProvider` / `AuthController`.

---

### Task 7: Auth providers + controller — implement

**Files:**
- Create: `lib/features/auth/controllers/auth_providers.dart`
- Create: `lib/features/auth/controllers/auth_controller.dart`

- [ ] **Step 1: Write `lib/features/auth/controllers/auth_providers.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_user.dart';
import '../data/auth_repository.dart';
import '../data/supabase_auth_repository.dart';

/// Override in tests with a mock.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => SupabaseAuthRepository(),
);

/// Stream of the current user; null when signed out.
final authStateProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).currentUserChanges();
});

/// Synchronous current user accessor for non-reactive call sites.
final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});
```

- [ ] **Step 2: Write `lib/features/auth/controllers/auth_controller.dart`**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import 'auth_providers.dart';

/// Holds the in-flight state of sign-in / sign-up / sign-out operations.
/// `AsyncValue.data(null)` = idle; `AsyncValue.loading()` = in flight;
/// `AsyncValue.error()` = last op failed (surface to UI).
final authControllerProvider =
    AsyncNotifierProvider<AuthController, void>(AuthController.new);

class AuthController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> signUp({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signUpWithEmail(email: email, password: password),
    );
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_repo.signOut);
  }
}
```

- [ ] **Step 3: Run tests to verify they pass**

```bash
flutter test test/features/auth/auth_controller_test.dart
```
Expected: 3 tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/features/auth/controllers/ test/features/auth/auth_controller_test.dart
git commit -m "feat(auth): add AuthController + providers with tests"
```

---

### Task 8: Shared auth form widgets

**Files:**
- Create: `lib/features/auth/ui/auth_form_widgets.dart`

- [ ] **Step 1: Write the file**

```dart
import 'package:flutter/material.dart';

class EmailField extends StatelessWidget {
  const EmailField({super.key, required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      autocorrect: false,
      textCapitalization: TextCapitalization.none,
      autofillHints: const [AutofillHints.email],
      decoration: const InputDecoration(
        labelText: 'Email',
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return 'Email is required';
        if (!value.contains('@') || !value.contains('.')) {
          return 'Enter a valid email';
        }
        return null;
      },
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Password',
    this.isNew = false,
  });
  final TextEditingController controller;
  final String label;
  final bool isNew;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: [
        widget.isNew ? AutofillHints.newPassword : AutofillHints.password,
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: (v) {
        final value = v ?? '';
        if (value.isEmpty) return 'Password is required';
        if (widget.isNew && value.length < 8) {
          return 'At least 8 characters';
        }
        return null;
      },
    );
  }
}

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isLoading,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/auth/ui/auth_form_widgets.dart
git commit -m "feat(auth): shared email/password form widgets"
```

---

### Task 9: Sign-in screen — failing widget test

**Files:**
- Create: `test/features/auth/sign_in_screen_test.dart`

- [ ] **Step 1: Write the test**

```dart
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
    when(() => repo.currentUserChanges())
        .thenAnswer((_) => Stream<AppUser?>.value(null));
    when(() => repo.currentUser).thenReturn(null);
  });

  Widget wrap() => ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: SignInScreen()),
      );

  testWidgets('shows email + password fields and a Sign in button',
      (tester) async {
    await tester.pumpWidget(wrap());
    expect(find.text('Sign in'), findsWidgets);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('blocks submit when email is empty', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    verifyNever(() => repo.signInWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ));
  });

  testWidgets('calls repository on valid submit', (tester) async {
    when(() => repo.signInWithEmail(
          email: 'a@b.co',
          password: 'secret123',
        )).thenAnswer((_) async {});

    await tester.pumpWidget(wrap());
    await tester.enterText(find.byType(TextFormField).at(0), 'a@b.co');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    verify(() => repo.signInWithEmail(
          email: 'a@b.co',
          password: 'secret123',
        )).called(1);
  });
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
flutter test test/features/auth/sign_in_screen_test.dart
```
Expected: failures on missing `SignInScreen`.

---

### Task 10: Sign-in screen — implement

**Files:**
- Create: `lib/features/auth/ui/sign_in_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../data/auth_repository.dart';
import 'auth_form_widgets.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;
    final error = state.error;

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && mounted) {
        final err = next.error;
        final msg = err is AuthException ? err.message : 'Sign-in failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EmailField(controller: _email),
                  const SizedBox(height: 16),
                  PasswordField(controller: _password),
                  const SizedBox(height: 24),
                  SubmitButton(
                    label: 'Sign in',
                    isLoading: loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => context.go('/auth/sign-up'),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                  if (error != null && error is! AuthException)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Something went wrong. Please try again.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run sign-in tests**

```bash
flutter test test/features/auth/sign_in_screen_test.dart
```
Expected: 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/ui/sign_in_screen.dart test/features/auth/sign_in_screen_test.dart
git commit -m "feat(auth): sign-in screen + widget tests"
```

---

### Task 11: Sign-up screen

**Files:**
- Create: `lib/features/auth/ui/sign_up_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../data/auth_repository.dart';
import 'auth_form_widgets.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
    if (mounted && !ref.read(authControllerProvider).hasError) {
      setState(() => _submitted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final loading = state.isLoading;

    ref.listen(authControllerProvider, (_, next) {
      if (next.hasError && mounted) {
        final err = next.error;
        final msg = err is AuthException ? err.message : 'Sign-up failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _submitted ? _verifyEmailMessage() : _form(loading),
        ),
      ),
    );
  }

  Widget _form(bool loading) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmailField(controller: _email),
            const SizedBox(height: 16),
            PasswordField(controller: _password, isNew: true),
            const SizedBox(height: 24),
            SubmitButton(
              label: 'Create account',
              isLoading: loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: loading ? null : () => context.go('/auth/sign-in'),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verifyEmailMessage() {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Check your email', style: t.titleLarge),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to ${_email.text.trim()}. '
          'Tap it to activate your account, then sign in.',
          style: t.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go('/auth/sign-in'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify analyze clean**

```bash
flutter analyze
```
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/features/auth/ui/sign_up_screen.dart
git commit -m "feat(auth): sign-up screen with verify-email confirmation"
```

---

### Task 12: Tab stub screens

**Files:**
- Create: `lib/features/calendar/ui/calendar_screen.dart`
- Create: `lib/features/alerts/ui/alerts_screen.dart`
- Create: `lib/features/family/ui/family_screen.dart`

- [ ] **Step 1: Write `lib/features/calendar/ui/calendar_screen.dart`**

```dart
import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Stub(title: 'Calendar', subtitle: 'Coming in Phase 5');
  }
}

class _Stub extends StatelessWidget {
  const _Stub({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: t.displayMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Write `lib/features/alerts/ui/alerts_screen.dart`**

```dart
import 'package:flutter/material.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Alerts', style: t.displayMedium),
            const SizedBox(height: 8),
            Text('Coming in Phase 5', style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write `lib/features/family/ui/family_screen.dart`**

```dart
import 'package:flutter/material.dart';

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Family')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('People & Shares', style: t.displayMedium),
            const SizedBox(height: 8),
            Text('Coming in Phase 6', style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add lib/features/calendar lib/features/alerts lib/features/family
git commit -m "feat(shell): add Calendar/Alerts/Family tab stubs"
```

---

### Task 13: Empty Home screen

**Files:**
- Create: `lib/features/home/ui/home_screen.dart`

- [ ] **Step 1: Write the screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/auth_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final t = Theme.of(context).textTheme;
    final greeting = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : user?.email.split('@').first ?? 'there';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Good morning,', style: t.bodyLarge),
                        Text(greeting, style: t.displayMedium),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Sign out',
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No items yet', style: t.titleLarge),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first item. Items, attachments, '
                        'and reminders arrive in Phase 2.',
                        style: t.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/home/
git commit -m "feat(home): empty home with greeting + sign-out"
```

---

### Task 14: AppShell with bottom nav

**Files:**
- Create: `lib/app/shell/app_shell.dart`
- Delete: `lib/app/shell/placeholder_home.dart`

- [ ] **Step 1: Write `lib/app/shell/app_shell.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.calendar_month_outlined),
      selectedIcon: Icon(Icons.calendar_month),
      label: 'Calendar',
    ),
    NavigationDestination(
      icon: Icon(Icons.notifications_outlined),
      selectedIcon: Icon(Icons.notifications),
      label: 'Alerts',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outlined),
      selectedIcon: Icon(Icons.people),
      label: 'Family',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: _destinations,
        onDestinationSelected: (i) => navigationShell.goBranch(
          i,
          initialLocation: i == navigationShell.currentIndex,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add Item arrives in Phase 2')),
        ),
        tooltip: 'Add item',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
```

- [ ] **Step 2: Delete the placeholder file**

```bash
rm lib/app/shell/placeholder_home.dart
```

- [ ] **Step 3: Commit**

```bash
git add lib/app/shell/
git commit -m "feat(shell): bottom-nav app shell with centered FAB"
```

---

### Task 15: Router with auth guard — failing test

**Files:**
- Create: `test/app/router/app_router_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
    when(() => repo.currentUserChanges())
        .thenAnswer((_) => Stream<AppUser?>.value(user));
    return ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
  }

  testWidgets('unauthenticated user is redirected to /auth/sign-in',
      (tester) async {
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
    expect(router.routerDelegate.currentConfiguration.uri.path,
        '/auth/sign-in');
  });

  testWidgets('authenticated user landing on /auth is redirected to /home',
      (tester) async {
    final user = const AppUser(id: 'u1', email: 'a@b.co');
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
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
flutter test test/app/router/app_router_test.dart
```
Expected: failure — `appRouterProvider` undefined.

---

### Task 16: Router with auth guard — implement

**Files:**
- Create: `lib/app/router/app_router.dart`

- [ ] **Step 1: Write the router**

```dart
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
      GoRoute(
        path: '/auth/sign-in',
        builder: (_, __) => const SignInScreen(),
      ),
      GoRoute(
        path: '/auth/sign-up',
        builder: (_, __) => const SignUpScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/calendar',
              builder: (_, __) => const CalendarScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/alerts',
              builder: (_, __) => const AlertsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/family',
              builder: (_, __) => const FamilyScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod auth changes into go_router's refresh mechanism.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(this._ref) {
    _sub = _ref.listen<AsyncValue<dynamic>>(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
  }
  final Ref _ref;
  late final ProviderSubscription<AsyncValue<dynamic>> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
```

- [ ] **Step 2: Run router test**

```bash
flutter test test/app/router/app_router_test.dart
```
Expected: 2 tests pass.

- [ ] **Step 3: Commit**

```bash
git add lib/app/router/ test/app/router/
git commit -m "feat(router): go_router with auth redirect guard"
```

---

### Task 17: Wire main.dart to router + Supabase init

**Files:**
- Modify: `lib/main.dart`
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Overwrite `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
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
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
```

- [ ] **Step 2: Overwrite `test/widget_test.dart`** so it doesn't try to init Supabase

```dart
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
    when(() => repo.currentUserChanges())
        .thenAnswer((_) => Stream<AppUser?>.value(null));

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
```

- [ ] **Step 3: Run all tests**

```bash
flutter test
```
Expected: all tests pass.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart test/widget_test.dart
git commit -m "feat(app): boot via MaterialApp.router + Supabase init"
```

---

### Task 18: Profile bootstrap on first sign-in

Profiles row must exist for every user. We trigger it on first auth event.

**Files:**
- Create: `supabase/migrations/0001_profiles.sql`
- Modify: `lib/features/auth/data/supabase_auth_repository.dart`

- [ ] **Step 1: Create `supabase/migrations/0001_profiles.sql`**

```sql
-- Profile row per auth user
create table if not exists public.profiles (
  id uuid primary key references auth.users on delete cascade,
  display_name text,
  default_reminder_offsets int[] not null default '{7,1}',
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own" on public.profiles
  for select using (auth.uid() = id);

create policy "profiles_insert_own" on public.profiles
  for insert with check (auth.uid() = id);

create policy "profiles_update_own" on public.profiles
  for update using (auth.uid() = id);
```

- [ ] **Step 2: Apply the migration manually in Supabase**

In the Supabase dashboard:
- SQL Editor → New query → paste the migration → Run
- Confirm `public.profiles` shows in Table editor with RLS enabled

- [ ] **Step 3: Add profile bootstrap to `SupabaseAuthRepository.currentUserChanges`**

Replace the existing `currentUserChanges` body in `lib/features/auth/data/supabase_auth_repository.dart` with:

```dart
  @override
  Stream<AppUser?> currentUserChanges() async* {
    yield currentUser;
    await for (final event in _client.auth.onAuthStateChange) {
      final user = event.session?.user;
      if (user != null && event.event == sb.AuthChangeEvent.signedIn) {
        await _ensureProfile(user);
      }
      yield _toAppUser(user);
    }
  }

  Future<void> _ensureProfile(sb.User user) async {
    await _client.from('profiles').upsert({
      'id': user.id,
      'display_name': user.userMetadata?['display_name'],
    }, onConflict: 'id', ignoreDuplicates: true);
  }
```

- [ ] **Step 4: Verify analyze + tests still pass**

```bash
flutter analyze && flutter test
```
Expected: no issues, all tests green.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/data/supabase_auth_repository.dart supabase/
git commit -m "feat(auth): create profile row on first sign-in"
```

---

### Task 19: Manual smoke test on web

The web target is the fastest way to verify the full auth loop without a simulator.

- [ ] **Step 1: Create `.env.local` with your Supabase values (gitignored)**

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

- [ ] **Step 2: Run on Chrome**

```bash
flutter run -d chrome --dart-define-from-file=.env.local
```
Expected: app opens, redirects to `/auth/sign-in`.

- [ ] **Step 3: Sign up**

- Enter `you+test1@yourdomain.com` and a password ≥ 8 chars
- Tap **Create account**
- See "Check your email" screen

- [ ] **Step 4: Click the verification link in your inbox**

- [ ] **Step 5: Sign in**

- Back in the app, navigate to `/auth/sign-in`
- Enter the same credentials → Sign in
- Expected: redirected to `/home` showing greeting based on email prefix
- Verify in Supabase dashboard → Table editor → `profiles` a new row exists for this user

- [ ] **Step 6: Sign out via the logout icon on Home**
- Expected: redirected back to `/auth/sign-in`

---

### Task 20: README + tag v0.2-auth

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Replace the "Run locally" block in `README.md`** with:

```markdown
## Run locally

Copy your Supabase URL + anon key into `.env.local` (gitignored):

```
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

```bash
flutter pub get
flutter run --dart-define-from-file=.env.local
flutter run -d chrome --dart-define-from-file=.env.local   # web preview
```
```

- [ ] **Step 2: Commit, tag, push**

```bash
git add README.md
git commit -m "docs: README run-locally instructions for Supabase env"
git tag -a v0.2-auth -m "Phase 1: Supabase + email/password auth + app shell"
git push
git push --tags
```

---

## D. Phase 1 exit gate

- [ ] `dart format --set-exit-if-changed .` — clean
- [ ] `flutter analyze --fatal-infos` — `No issues found!`
- [ ] `flutter test` — all green (auth controller, sign-in widget, router, app smoke)
- [ ] Manual smoke (Task 19) — sign up → verify → sign in → see profile row → sign out — all working
- [ ] CI green on `main`
- [ ] Tag `v0.2-auth` pushed

---

## E. Risks & notes

| Risk | Mitigation |
|---|---|
| Supabase email verification link goes to a `localhost` redirect that breaks on phone | Add a real deep-link redirect in Phase 1b. For dev, click the link in the browser where you ran `flutter run -d chrome`. |
| `.env.local` accidentally committed | `.gitignore` already covers `.env.local` via `.env*`. |
| `dart run build_runner` fails on first run due to cache | Run with `--delete-conflicting-outputs` (Task 3 already does). |
| `pdfx` web warnings | Ignore — package-internal, V1 doesn't ship web. |
| Bringing in Google/Apple sign-in later changes the sign-in screen UI | The screen is intentionally minimal; adding two more buttons is a 15-min change. No refactor needed. |

---

## Self-Review

**Spec coverage (Phase 1 slice):** ✓ Supabase wired, ✓ email auth, ✓ profile bootstrap with `default_reminder_offsets`, ✓ 5-slot bottom nav (4 tabs + centered FAB), ✓ empty Home with greeting + sign-out, ✓ tab stubs for Calendar/Alerts/Family. Out-of-scope explicitly documented.

**Placeholder scan:** no "TBD" / "implement later" / "similar to". Manual steps in Task M1 and Task 18 Step 2 are user actions in Supabase UI, with exact instructions.

**Type consistency:** `AppUser` shape (id/email/displayName) matches across model, repository, providers, Home greeting. `AuthException` thrown from repo and unwrapped in screens. `authRepositoryProvider` / `authStateProvider` / `currentUserProvider` / `authControllerProvider` names consistent across providers file, controller, screens, router, and tests.
