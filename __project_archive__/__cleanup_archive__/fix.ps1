$ErrorActionPreference = "Stop"

function Write-Utf8NoBom([string]$path, [string]$content) {
  $dir = Split-Path $path -Parent
  if (!(Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $content, $utf8NoBom)
}

Write-Host "[A] Remove old files..." -ForegroundColor Yellow
Remove-Item -Force -ErrorAction SilentlyContinue "lib\app\app_router.dart"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\app\app_routes.dart"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\core\session.dart"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "lib\services"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue "lib\features\home"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\features\auth\presentation\pages\otp_screen.dart"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\features\auth\presentation\pages\otp_page.dart"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\features\auth\presentation\pages\login_page.dart"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\features\auth\presentation\pages\register_page.dart"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\features\auth\presentation\pages\email_login_screen.dart"
Remove-Item -Force -ErrorAction SilentlyContinue "lib\features\transactions\presentation\pages\create_transaction_page.dart"

Write-Host "[B] Write required pages..." -ForegroundColor Yellow

# --- register_screen.dart
Write-Utf8NoBom "lib\features\auth\presentation\pages\register_screen.dart" @"
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/role.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/user_service.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_input.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _country = TextEditingController(text: 'Haiti');
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _country.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final country = _country.text.trim();
    final email = _email.text.trim();
    final pass = _pass.text.trim();
    final confirm = _confirm.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Antre non ou')));
      return;
    }
    if (!Validators.isPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Telefòn pa valab')));
      return;
    }
    if (!Validators.isEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email pa valab')));
      return;
    }
    if (pass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modpas dwe gen 6+ karaktè')));
      return;
    }
    if (pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modpas yo pa menm')));
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthService.instance.register(email, pass);
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) {
        await UserService.instance.upsertUser(
          uid: u.uid,
          email: email,
          displayName: name,
          phone: phone,
          country: country.isEmpty ? 'Haiti' : country,
          role: UserRole.customer,
          isActive: true,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kont lan kreye ')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erè: \$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kreye kont')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            AppInput(controller: _name, label: 'Non konplè'),
            const SizedBox(height: 10),
            AppInput(controller: _phone, label: 'Telefòn', keyboardType: TextInputType.phone),
            const SizedBox(height: 10),
            AppInput(controller: _country, label: 'Peyi (eg: Haiti)'),
            const SizedBox(height: 10),
            AppInput(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            AppInput(
              controller: _pass,
              label: 'Modpas',
              obscure: _obscure,
              suffix: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              ),
            ),
            const SizedBox(height: 10),
            AppInput(controller: _confirm, label: 'Konfime modpas', obscure: _obscure),
            const SizedBox(height: 12),
            AppButton(text: 'Kreye kont', onPressed: _register, loading: _loading),
          ],
        ),
      ),
    );
  }
}
"@

Write-Host "[C] Done. Run: flutter clean; flutter pub get; flutter analyze" -ForegroundColor Green
