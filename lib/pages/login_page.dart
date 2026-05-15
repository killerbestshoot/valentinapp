import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;
  bool showPassword = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> login() async {
    final email = emailCtrl.text.trim();
    final password = passCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Antre yon email ki valid.');
      return;
    }

    if (password.length < 6) {
      _showMessage('Modpas dwe gen omwen 6 karakte.');
      return;
    }

    try {
      setState(() => loading = true);

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomePage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(_authErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email la pa valid.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'Kont sa pa jwenn oswa enfomasyon yo pa bon.';
      case 'wrong-password':
        return 'Modpas la pa bon.';
      case 'too-many-requests':
        return 'Twop tantativ. Tann yon ti moman epi eseye anko.';
      case 'network-request-failed':
        return 'Rezo a pa disponib. Verifye koneksyon an.';
      default:
        return e.message ?? 'Login error';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 860;

            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: wide
                      ? Row(
                          children: [
                            const Expanded(child: _LoginBrandPanel()),
                            const SizedBox(width: 28),
                            Expanded(child: _buildLoginPanel(theme)),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _LoginBrandPanel(compact: true),
                            const SizedBox(height: 20),
                            _buildLoginPanel(theme),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginPanel(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E7DC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Konekte',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF173B24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Antre nan kont VOUPVAPCASH ou pou jere tranzaksyon yo.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF607064),
              ),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passCtrl,
              obscureText: !showPassword,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) {
                if (!loading) login();
              },
              decoration: const InputDecoration(
                labelText: 'Modpas',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ).copyWith(
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Kache modpas' : 'Montre modpas',
                  icon: Icon(
                    showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () {
                    setState(() => showPassword = !showPassword);
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F7A3A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: loading ? null : login,
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Konekte',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginBrandPanel extends StatelessWidget {
  const _LoginBrandPanel({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(compact ? 22 : 32),
      decoration: BoxDecoration(
        color: const Color(0xFF173B24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F6E9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              color: Color(0xFF1F7A3A),
              size: 30,
            ),
          ),
          SizedBox(height: compact ? 18 : 32),
          Text(
            'VOUPVAPCASH',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enterprise wallet, services, receipts, and agent operations in one secure workspace.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFDDEBDD),
              height: 1.45,
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 32),
            const _BrandMetric(
              icon: Icons.receipt_long_outlined,
              label: 'Receipt validation',
            ),
            const SizedBox(height: 12),
            const _BrandMetric(
              icon: Icons.shield_outlined,
              label: 'Role-based access',
            ),
            const SizedBox(height: 12),
            const _BrandMetric(
              icon: Icons.payments_outlined,
              label: 'Wallet and payout control',
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandMetric extends StatelessWidget {
  const _BrandMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9CE3A8), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
