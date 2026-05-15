import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'commission_test_page.dart';
import 'withdraw_request_page.dart';
import 'withdraw_approval_page.dart';
import 'run_commission_page.dart';

class PayoutAdminHubPage extends StatelessWidget {
  const PayoutAdminHubPage({super.key});

  Widget buildButton(BuildContext context, String title, Widget page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SizedBox(
        height: 46,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            );
          },
          child: Text(title),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'NO USER';
    final email = user?.email ?? 'NO EMAIL';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Hub'),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Dekonekte',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'PAYOUT HUB LOADED',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text('AUTH UID: $uid'),
            Text('AUTH EMAIL: $email'),
            const SizedBox(height: 16),
            buildButton(
              context,
              'Commission Dashboard',
const SizedBox.shrink(),
            ),
            buildButton(
              context,
              'Commission Test',
              const CommissionTestPage(),
            ),
            buildButton(
              context,
              'Run Weekly Commission',
              const RunCommissionPage(),
            ),
            buildButton(
              context,
              'Withdraw Request',
              const WithdrawRequestPage(),
            ),
            buildButton(
              context,
              'Withdraw Approval',
              const WithdrawApprovalPage(),
            ),
          ],
        ),
      ),
    );
  }
}
