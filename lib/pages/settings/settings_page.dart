import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/widgets/dashboard_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('Dekonekte'),
              content: const Text('Eske ou vle dekonekte kounye a?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Anile'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.logout),
                  label: const Text('Dekonekte'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!ok) return;
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

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
          subtitle: 'Aks ak login kont lan',
          onTap: () {},
        ),
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.notifications_outlined,
          title: 'Notifikasyon',
          subtitle: 'Preferans notifikasyon yo',
          onTap: () {},
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 12),
        DashboardActionTile(
          icon: Icons.info_outline,
          title: 'A pwopo',
          subtitle: 'VOUPVAPCASH production build',
          onTap: () {},
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
