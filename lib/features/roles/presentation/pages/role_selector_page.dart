import 'package:flutter/material.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/session/app_session.dart';
import '../../../dashboard/presentation/pages/services_dashboard_page.dart';

class RoleSelectorPage extends StatelessWidget {
  const RoleSelectorPage({super.key});

  void _selectRole(BuildContext context, AppRole role) {
    AppSession.currentRole = role;

    switch (role) {
      case AppRole.owner:
        AppSession.currentUserName = 'Pwopriyet Antrepriz';
        break;
      case AppRole.admin:
        AppSession.currentUserName = 'Administrat Operasyon';
        break;
      case AppRole.agent:
        AppSession.currentUserName = 'Ajan MonCash';
        break;
      case AppRole.client:
        AppSession.currentUserName = 'Kliyan Platfm';
        break;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const ServicesDashboardPage(),
      ),
    );
  }

  Widget _roleCard(
    BuildContext context, {
    required AppRole role,
    required IconData icon,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _selectRole(context, role),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42),
              const SizedBox(height: 12),
              Text(
                role.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                role.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chwazi wl antrepriz la'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 0.95,
          children: [
            _roleCard(
              context,
              role: AppRole.owner,
              icon: Icons.workspace_premium,
            ),
            _roleCard(
              context,
              role: AppRole.admin,
              icon: Icons.admin_panel_settings,
            ),
            _roleCard(
              context,
              role: AppRole.agent,
              icon: Icons.badge,
            ),
            _roleCard(
              context,
              role: AppRole.client,
              icon: Icons.person,
            ),
          ],
        ),
      ),
    );
  }
}
