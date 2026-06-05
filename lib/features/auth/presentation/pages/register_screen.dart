import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../domain/login_use_case.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final LoginUseCase _loginUseCase = LoginUseCase();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _email.text.trim();
    final pass = _pass.text;

    if (email.isEmpty || !email.contains('@')) {
      _toast('Antre yon email ki valid.');
      return;
    }
    if (pass.length < 6) {
      _toast('Modpas dwe gen omwen 6 chif/lt.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _loginUseCase.signUp(email: email, password: pass);

      if (!mounted) return;
      context.go('/dashboard');
    } catch (error) {
      _toast(_niceAuthError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _niceAuthError(Object error) {
    final code = _firebaseErrorCode(error);
    switch (code) {
      case 'email-already-in-use':
        return 'Email sa deja itilize.';
      case 'invalid-email':
        return 'Email la pa valid.';
      case 'weak-password':
        return 'Modpas la fb. Mete 6+ karakt.';
      case 'network-request-failed':
        return 'Pa gen entnt / rezo a gen pwoblm.';
      default:
        return error.toString().replaceFirst('Bad state: ', '');
    }
  }

  String? _firebaseErrorCode(Object error) {
    final text = error.toString();
    final match = RegExp(r'firebase_auth/([a-z0-9-]+)').firstMatch(text);
    return match?.group(1);
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kreye kont ajan'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pass,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Modpas (min 6)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Kreye kont'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/login'),
              child: const Text('Mwen gen kont deja'),
            ),
          ],
        ),
      ),
    );
  }
}
