import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mon_premye_app/core/network/api_base.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/data/http_auth_repository.dart';
import 'package:mon_premye_app/pages/notifications/notifications_page.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Paramèt kont lan.
///
/// Sou backend SQLite la, chanje modpas se yon fòm dirèk — pa yon imel reset.
/// Serveur a verifye ansyen modpas la, epi li fè TOUT sesyon yo tonbe: si yon
/// moun te gen yon sesyon vòlè, li pèdi l la menm.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Dekonekte'),
            content: const Text('Eske ou vle dekonekte kounye a?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anile'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.logout),
                label: const Text('Dekonekte'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;
    await AuthRepositoryProvider.instance.signOut();

    // Paramèt louvri ak `Navigator.push`: wout sa a rete ANWO pil GoRouter la.
    // San `go`, moun nan rete sou ekran Paramèt, "konekte" ak yon sesyon vid.
    if (context.mounted) context.go('/');
  }

  Future<void> _changePassword(BuildContext context) async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Chanje modpas'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Modpas aktyèl',
                    ),
                    validator: (v) =>
                        (v ?? '').isEmpty ? 'Antre modpas aktyèl la.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nouvo modpas',
                      helperText: 'Omwen 8 karaktè.',
                    ),
                    validator: (v) => (v ?? '').length < 8
                        ? 'Omwen 8 karaktè.'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ou pral dekonekte sou tout aparèy apre chanjman an.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anile'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext, true);
                  }
                },
                child: const Text('Chanje'),
              ),
            ],
          ),
        ) ??
        false;

    final currentPassword = currentCtrl.text;
    final newPassword = newCtrl.text;
    // Kontwolè yo kenbe modpas an klè: nou libere yo tou swit.
    currentCtrl.dispose();
    newCtrl.dispose();

    if (!ok) return;

    try {
      await HttpAuthRepository.instance.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (context.mounted) {
        _toast(context, 'Modpas chanje. Konekte ankò.');
        context.go('/');
      }
    } on ApiException catch (err) {
      if (context.mounted) _toast(context, err.message);
    }
  }

  void _showAbout(BuildContext context) {
    final user = AuthRepositoryProvider.instance.currentUser;

    showAboutDialog(
      context: context,
      applicationName: 'VOUPVAPCASH',
      applicationVersion: '1.0.0+1',
      children: [
        const SizedBox(height: 12),
        _AboutRow(label: 'Itilizatè', value: user?.email ?? '—'),
        _AboutRow(label: 'Wòl', value: user?.role.name ?? '—'),
        _AboutRow(label: 'Antrepriz', value: user?.enterpriseName ?? '—'),
        const _AboutRow(label: 'Backend', value: 'SQLite'),
        _AboutRow(label: 'Serveur', value: ApiBase.origin),
        const _AboutRow(
          label: 'Pasrèl peman',
          value: 'Bazik (MonCash / NatCash)',
        ),
      ],
    );
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthRepositoryProvider.instance.currentUser;

    return DashboardPage(
      title: 'Paramèt',
      children: [
        DashboardHero(
          icon: Icons.settings_outlined,
          title: 'VOUPVAPCASH settings',
          subtitle: user?.email ?? 'User konekte',
        ),
        const SizedBox(height: 18),
        DashboardActionTile(
          icon: Icons.security_outlined,
          title: 'Sekirite',
          subtitle: 'Chanje modpas ou',
          onTap: () => _changePassword(context),
        ),
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.notifications_outlined,
          title: 'Notifikasyon',
          subtitle: 'Wè notifikasyon antrepriz la',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          ),
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.info_outline,
          title: 'A pwopo',
          subtitle: 'Vèsyon ak konfigirasyon',
          onTap: () => _showAbout(context),
          color: const Color(0xFF525252),
        ),
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.logout,
          title: 'Dekonekte',
          subtitle: 'Sòti sou kont aktyèl la',
          onTap: () => _logout(context),
          color: const Color(0xFFB91C1C),
        ),
      ],
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
