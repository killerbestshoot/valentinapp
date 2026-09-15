import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/users/data/users_api.dart';

/// Kreye yon staff nan antrepriz la.
///
/// SOU BACKEND SQLITE LA, KREYE YON KONT PA DEKONEKTE OU.
///
/// Ak Firebase, `createUserWithEmailAndPassword` te konekte nouvo itilizatè a
/// nan plas admin nan — se konsa API a mache sou kliyan an. Nou te oblije
/// avèti admin nan epi voye l sou paj koneksyon an apre chak kreyasyon.
/// Isit la kreyasyon an fèt sèvè-bò: sesyon admin nan pa touche.
class CreateAgentScreen extends StatefulWidget {
  const CreateAgentScreen({super.key});

  @override
  State<CreateAgentScreen> createState() => _CreateAgentScreenState();
}

class _CreateAgentScreenState extends State<CreateAgentScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  String role = 'agent';
  String currency = 'USD';
  bool loading = false;
  String message = '';
  bool success = false;

  static const roles = ['agent', 'admin', 'client'];

  /// Deviz wallet la. Li FIKSE apre kreyasyon an: tout sòld, debi ak
  /// konvèsyon Bazik chita sou li.
  static const currencies = ['HTG', 'MXN', 'USD'];

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      message = '';
      success = false;
    });

    try {
      final created = await UsersApi.instance.create(
        email: emailCtrl.text.trim(),
        password: passCtrl.text.trim(),
        displayName: nameCtrl.text.trim(),
        role: role,
        currency: currency,
      );

      if (!mounted) return;
      setState(() {
        success = true;
        message = 'Kont kreye: ${created.email} (${created.role}). '
            'Wallet li kreye vid an $currency.';
      });

      nameCtrl.clear();
      emailCtrl.clear();
      passCtrl.clear();
    } on ApiException catch (err) {
      if (mounted) setState(() => message = err.message);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvo staff')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Non konplè',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Antre non an.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Imel',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                    return 'Imel la pa valid.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Modpas tanporè',
                  helperText:
                      'Minimòm 8 karaktè. Staff la ap oblije chanje l nan '
                      'premye koneksyon li.',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v ?? '').trim().length < 8
                    ? 'Modpas la dwe gen omwen 8 karaktè.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                  labelText: 'Wòl',
                  border: OutlineInputBorder(),
                ),
                items: roles
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: loading
                    ? null
                    : (value) => setState(() => role = value ?? 'agent'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: currency,
                decoration: const InputDecoration(
                  labelText: 'Deviz wallet la',
                  helperText:
                      'Li pa ka chanje apre. Yon rechaj nan yon lòt deviz ap '
                      'konvèti vè sa a.',
                  border: OutlineInputBorder(),
                ),
                items: currencies
                    .map((code) => DropdownMenuItem(
                          value: code,
                          child: Text(code),
                        ))
                    .toList(),
                onChanged: loading
                    ? null
                    : (value) => setState(() => currency = value ?? 'USD'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : _create,
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Kreye kont lan'),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: success
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(message),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
