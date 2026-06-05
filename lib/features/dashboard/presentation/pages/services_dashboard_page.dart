import 'package:flutter/material.dart';

import '../../../../core/config/app_brand.dart';
import '../../../../core/models/app_role.dart';
import '../../../../core/session/app_session.dart';
import '../../../auth/presentation/pages/auth_entry_page.dart';
import 'package:mon_premye_app/pages/clients/clients_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../transactions/presentation/pages/my_transactions_page.dart';
import '../../../transactions/presentation/pages/new_transaction_page.dart';

class ServicesDashboardPage extends StatelessWidget {
  const ServicesDashboardPage({super.key});

  String get _enterpriseName {
    final name = AppSession.enterpriseName.trim();
    if (name.isEmpty) return AppBrand.defaultEnterpriseName;
    return name;
  }

  String get _roleTitle {
    switch (AppSession.currentRole) {
      case AppRole.owner:
        return 'Dashboard Pwopriyet';
      case AppRole.admin:
        return 'Dashboard Administrat';
      case AppRole.agent:
        return 'Dashboard Ajan';
      case AppRole.client:
        return 'Dashboard Kliyan';
    }
  }

  String get _roleSubtitle {
    switch (AppSession.currentRole) {
      case AppRole.owner:
        return 'Ou kontwole tout antrepriz la';
      case AppRole.admin:
        return 'Ou jere operasyon ak ekip la';
      case AppRole.agent:
        return 'Ou antre svis ak tranzaksyon yo';
      case AppRole.client:
        return 'Ou suiv svis ou resevwa yo';
    }
  }

  bool get _canCreateTransaction {
    return AppSession.currentRole == AppRole.owner ||
        AppSession.currentRole == AppRole.admin ||
        AppSession.currentRole == AppRole.agent;
  }

  bool get _canViewReports {
    return AppSession.currentRole == AppRole.owner ||
        AppSession.currentRole == AppRole.admin;
  }

  bool get _canViewClients {
    return AppSession.currentRole == AppRole.owner ||
        AppSession.currentRole == AppRole.admin ||
        AppSession.currentRole == AppRole.agent;
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _summaryTile(
        icon: Icons.business,
        title: _enterpriseName,
        value: '${AppSession.currentRole.label}  ${AppSession.currentUserName}',
        subtitle: _roleSubtitle,
      ),
      const _Spacer16(),
      _menuGrid(context),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_roleTitle),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              AppSession.logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthEntryPage()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: cards,
        ),
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            child: Icon(icon),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuGrid(BuildContext context) {
    final items = <_MenuItem>[
      if (_canCreateTransaction)
        _MenuItem(
          title: 'Nouvo\ntranzaksyon',
          icon: Icons.add_card,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NewTransactionPage()),
            );
          },
        ),
      _MenuItem(
        title: 'Tranzaksyon\nmwen',
        icon: Icons.receipt_long,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyTransactionsPage()),
          );
        },
      ),
      if (_canViewClients)
        _MenuItem(
          title: 'Kliyan',
          icon: Icons.people,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClientsPage()),
            );
          },
        ),
      if (_canViewReports)
        _MenuItem(
          title: 'Rap',
          icon: Icons.bar_chart,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReportsPage()),
            );
          },
        ),
      _MenuItem(
        title: 'Paramt',
        icon: Icons.settings,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsPage()),
          );
        },
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.02,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon, size: 42),
                const SizedBox(height: 16),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  _MenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });
}

class _Spacer16 extends StatelessWidget {
  const _Spacer16();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 16);
  }
}
