import 'package:flutter/material.dart';
import '../../../transactions/presentation/pages/new_transaction_page.dart';
import '../../../transactions/presentation/pages/my_transactions_page.dart';
import 'package:mon_premye_app/pages/clients/clients_page.dart';
import '../../../reports/presentation/pages/reports_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  Widget _buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MonCash Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCard(
              context,
              icon: Icons.add_card,
              title: 'Nouvo tranzaksyon',
              page: const NewTransactionPage(),
            ),
            _buildCard(
              context,
              icon: Icons.receipt_long,
              title: 'Tranzaksyon mwen',
              page: const MyTransactionsPage(),
            ),
            _buildCard(
              context,
              icon: Icons.people,
              title: 'Kliyan',
              page: const ClientsPage(),
            ),
            _buildCard(
              context,
              icon: Icons.bar_chart,
              title: 'Rap',
              page: const ReportsPage(),
            ),
            _buildCard(
              context,
              icon: Icons.settings,
              title: 'Paramt',
              page: const SettingsPage(),
            ),
          ],
        ),
      ),
    );
  }
}
