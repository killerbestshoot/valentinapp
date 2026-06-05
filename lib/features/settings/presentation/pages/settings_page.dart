import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_brand.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/session/app_session.dart';
import '../../../auth/presentation/pages/auth_entry_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    AppSession.clear();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthEntryPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterpriseName = AppSession.enterpriseName.trim().isEmpty
        ? AppBrand.defaultEnterpriseName
        : AppSession.enterpriseName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramt'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                AppSession.currentUserName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${AppSession.currentUserEmail}\n${AppSession.currentRole.label}\n$enterpriseName',
              ),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Antrepriz'),
              subtitle: Text(enterpriseName),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.phone_android),
              title: Text('Aplikasyon'),
              subtitle: Text('${AppBrand.appTitle} - ${AppBrand.appVersion}'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Dekonekte'),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
    );
  }
}
