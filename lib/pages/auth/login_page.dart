import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mon_premye_app/core/session/session_store.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/domain/login_use_case.dart';
import 'package:mon_premye_app/services/auth/remember_me_service.dart';

enum _AuthMode { login, register }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  late final LoginUseCase _loginUseCase;

  _AuthMode _mode = _AuthMode.login;
  bool _loading = false;
  bool _resettingPassword = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _rememberMe = false;

  bool get _isLogin => _mode == _AuthMode.login;

  @override
  void initState() {
    super.initState();
    _loginUseCase = LoginUseCase(repository: widget.authRepository);
    _loadRememberedLogin();
    _announceTimeout();
  }

  /// Si se minitè inaktivite a ki te dekonekte moun nan, nou di l poukisa.
  /// San sa li ta panse app la tonbe nan mitan travay li.
  void _announceTimeout() {
    if (!SessionStore.instance.consumeTimeoutNotice()) return;

    final minutes = SessionStore.instance.idleTimeout.inMinutes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showMessage(
        'Sesyon an fèmen apre $minutes minit san aktivite. Konekte ankò.',
      );
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedLogin() async {
    final remembered = await RememberMeService.instance.load();
    if (!mounted) return;

    setState(() {
      _rememberMe = remembered.rememberMe;
      _emailCtrl.text = remembered.email;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_loading || !_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    setState(() => _loading = true);

    try {
      if (_isLogin) {
        await _loginUseCase.execute(
          email: email,
          password: password,
        );
      } else {
        await _loginUseCase.signUp(
          email: email,
          password: password,
        );
      }

      await RememberMeService.instance.save(
        rememberMe: _rememberMe,
        email: email,
      );

      if (!mounted) return;
      context.go('/');
    } catch (e) {
      _showMessage(_authErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailCtrl.text.trim();
    final emailError = _validateEmail(email);

    if (emailError != null) {
      _showMessage(emailError);
      return;
    }

    setState(() => _resettingPassword = true);

    try {
      await RememberMeService.instance.save(
        rememberMe: true,
        email: email,
      );

      if (!mounted) return;
      setState(() => _rememberMe = true);
      _showMessage(
          'Reset modpas la pa branche sou nouvo auth service la ankò.');
    } catch (e) {
      _showMessage(_authErrorMessage(e));
    } finally {
      if (mounted) {
        setState(() => _resettingPassword = false);
      }
    }
  }

  void _toggleMode() {
    setState(() {
      _mode = _isLogin ? _AuthMode.register : _AuthMode.login;
      _passCtrl.clear();
      _confirmCtrl.clear();
      _showPassword = false;
      _showConfirmPassword = false;
    });
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Antre yon email ki valid.';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (_isLogin) return null;
    if ((value ?? '').trim().length < 2) {
      return 'Antre non moun nan.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 6) {
      return 'Modpas dwe gen omwen 6 karakte.';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (_isLogin) return null;
    if ((value ?? '') != _passCtrl.text) {
      return 'Modpas yo pa menm.';
    }
    return null;
  }

  /// Tradui erè serveur a an mesaj pou itilizatè a.
  ///
  /// Anvan, fonksyon sa a t ap chèche kòd `firebase_auth/...` nan tèks erè a.
  /// Depi backend la se SQLite, kòd sa yo pa janm rive: tout erè te tonbe nan
  /// branch `default` la, ki te montre erè brit la bay itilizatè a.
  String _authErrorMessage(Object error) {
    if (error is ApiException) {
      switch (error.code) {
        case 'invalid_credentials':
          return 'Imel oswa modpas pa bon.';
        case 'account_disabled':
          return 'Kont sa a dezaktive. Kontakte administratè a.';
        case 'too_many_attempts':
          return error.message;
        case 'email_taken':
          return 'Imel sa a deja gen yon kont.';
        case 'invalid_email':
          return 'Imel la pa valid.';
        case 'weak_password':
          return error.message;
        case 'already_bootstrapped':
          // "Kreye kont" mache sèlman pou premye owner an. Apre sa, se yon
          // administratè ki kreye kont staff yo.
          return 'Kreyasyon kont fèmen. Mande yon administratè pou l kreye kont ou.';
        case 'network_error':
          return error.message;
        default:
          return error.message;
      }
    }

    return 'Yon erè rive. Eseye ankò.';
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
            final panelPadding = constraints.maxWidth < 420 ? 18.0 : 28.0;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(constraints.maxWidth < 420 ? 16 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Expanded(child: _LoginBrandPanel()),
                            const SizedBox(width: 28),
                            Expanded(
                              child: _buildAuthPanel(theme, panelPadding),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _LoginBrandPanel(compact: true),
                            const SizedBox(height: 20),
                            _buildAuthPanel(theme, panelPadding),
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

  Widget _buildAuthPanel(ThemeData theme, double panelPadding) {
    return Container(
      padding: EdgeInsets.all(panelPadding),
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isLogin ? 'Konekte' : 'Kreye kont',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF173B24),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isLogin
                    ? 'Antre nan kont VOUPVAPCASH ou pou jere tranzaksyon yo.'
                    : 'Kreye yon kont client ak yon userId UUID v4.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF607064),
                ),
              ),
              const SizedBox(height: 28),
              if (!_isLogin) ...[
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  validator: _validateName,
                  decoration: const InputDecoration(
                    labelText: 'Non konple',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: _validateEmail,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.mail_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passCtrl,
                obscureText: !_showPassword,
                textInputAction:
                    _isLogin ? TextInputAction.done : TextInputAction.next,
                autofillHints: [
                  _isLogin ? AutofillHints.password : AutofillHints.newPassword,
                ],
                validator: _validatePassword,
                onFieldSubmitted: (_) {
                  if (_isLogin && !_loading) _submit();
                },
                decoration: const InputDecoration(
                  labelText: 'Modpas',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ).copyWith(
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Kache modpas' : 'Montre modpas',
                    icon: Icon(
                      _showPassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _showPassword = !_showPassword);
                    },
                  ),
                ),
              ),
              if (!_isLogin) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: !_showConfirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: _validateConfirmPassword,
                  onFieldSubmitted: (_) {
                    if (!_loading) _submit();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Konfime modpas',
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                    border: OutlineInputBorder(),
                  ).copyWith(
                    suffixIcon: IconButton(
                      tooltip: _showConfirmPassword
                          ? 'Kache modpas'
                          : 'Montre modpas',
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _buildRememberAndResetRow(),
              const SizedBox(height: 16),
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
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_isLogin ? Icons.login : Icons.person_add),
                            const SizedBox(width: 10),
                            Text(
                              _isLogin ? 'Konekte' : 'Kreye kont',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _loading ? null : _toggleMode,
                icon: Icon(_isLogin ? Icons.person_add_alt : Icons.login),
                label: Text(
                  _isLogin ? 'Kreye yon kont' : 'Mwen gen kont deja',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRememberAndResetRow() {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 4,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _loading
              ? null
              : () => setState(() => _rememberMe = !_rememberMe),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                value: _rememberMe,
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _rememberMe = value ?? false);
                      },
              ),
              const Text('Sonje mwen'),
            ],
          ),
        ),
        if (_isLogin)
          TextButton.icon(
            onPressed:
                (_loading || _resettingPassword) ? null : _sendPasswordReset,
            icon: _resettingPassword
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.help_outline),
            label: const Text('Modpas bliye?'),
          ),
      ],
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
