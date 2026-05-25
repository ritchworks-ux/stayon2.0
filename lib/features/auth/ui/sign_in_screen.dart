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
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text.trim(), password: _password.text);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
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
                  SubmitButton(label: 'Sign in', isLoading: loading, onPressed: _submit),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: loading ? null : () => context.go('/auth/sign-up'),
                    child: const Text("Don't have an account? Sign up"),
                  ),
                  if (error != null && error is! AuthException)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Something went wrong. Please try again.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
