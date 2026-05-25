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
    await ref
        .read(authControllerProvider.notifier)
        .signUp(email: _email.text.trim(), password: _password.text);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
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
            SubmitButton(label: 'Create account', isLoading: loading, onPressed: _submit),
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
