import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'wallet_dashboard_page.dart';
import 'wallet_topup_page.dart';
import 'wallet_topup_approval_page.dart';
import 'wallet_history_page.dart';

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  User? get _user => FirebaseAuth.instance.currentUser;

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _menuButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget page,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _open(context, page),
          icon: Icon(icon),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              title,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('OWNER DASHBOARD'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Icon(Icons.verified_user, size: 72),
                      const SizedBox(height: 14),
                      const Text(
                        'OWNER PANEL',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 26),
              _sectionTitle('WALLET MANAGEMENT'),
              _menuButton(
                context: context,
                title: 'Wallet Dashboard',
                icon: Icons.account_balance_wallet,
                page: const WalletDashboardPage(),
              ),
              _menuButton(
                context: context,
                title: 'Topup Wallet',
                icon: Icons.add_card,
                page: const WalletTopupPage(),
              ),
              _menuButton(
                context: context,
                title: 'Topup Approval',
                icon: Icons.approval,
                page: const WalletTopupApprovalPage(),
              ),
              _menuButton(
                context: context,
                title: 'Wallet History',
                icon: Icons.history,
                page: const WalletHistoryPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}