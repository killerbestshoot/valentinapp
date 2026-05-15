import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mon_premye_app/pages/agents_page.dart';
import 'package:mon_premye_app/pages/auth_debug_page.dart';
import 'package:mon_premye_app/pages/new_transaction_page.dart';
import 'package:mon_premye_app/pages/payout_page.dart';
import 'package:mon_premye_app/pages/run_commission_page.dart';
import 'package:mon_premye_app/pages/send_page.dart';
import 'package:mon_premye_app/pages/settings_page.dart';
import 'package:mon_premye_app/pages/topup_page.dart';
import 'package:mon_premye_app/pages/wallet_topup_approval_page.dart';

class OwnerDashboard extends StatelessWidget {
  final String enterpriseId;
  final String enterpriseName;

  const OwnerDashboard({
    super.key,
    this.enterpriseId = 'ENT-001',
    this.enterpriseName = 'VOUPVAPCASH',
  });

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _quickCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: SizedBox(
        height: 110,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enterpriseStream = FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterpriseId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
        title: const Text('OWNER DASHBOARD'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: enterpriseStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final ownerBalance = (data['ownerBalance'] is num)
              ? (data['ownerBalance'] as num).toDouble()
              : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OWNER INFO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text('Display name: Owner'),
                      const Text('Role: owner'),
                      Text('Enterprise: $enterpriseName'),
                      Text('Enterprise ID: $enterpriseId'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined,
                          size: 36),
                      const SizedBox(height: 12),
                      const Text(
                        'OWNER LIVE BALANCE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(enterpriseName),
                      const SizedBox(height: 10),
                      Text(
                        '${ownerBalance.toStringAsFixed(2)} USD',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'QUICK ACTIONS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _quickCard(
                    context: context,
                    icon: Icons.add_circle_outline,
                    title: 'New Tx',
                    onTap: () => _open(context, const NewTransactionPage()),
                  ),
                  const SizedBox(width: 12),
                  _quickCard(
                    context: context,
                    icon: Icons.send,
                    title: 'Send',
                    onTap: () => _open(context, const SendPage()),
                  ),
                  const SizedBox(width: 12),
                  _quickCard(
                    context: context,
                    icon: Icons.payments_outlined,
                    title: 'Payout',
                    onTap: () => _open(context, const PayoutPage()),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _quickCard(
                    context: context,
                    icon: Icons.phone_android_outlined,
                    title: 'Topup',
                    onTap: () => _open(context, const TopupPage()),
                  ),
                  const SizedBox(width: 12),
                  _quickCard(
                    context: context,
                    icon: Icons.groups_outlined,
                    title: 'Agents',
                    onTap: () => _open(context, const AgentsPage()),
                  ),
                  const SizedBox(width: 12),
                  _quickCard(
                    context: context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => _open(context, const SettingsPage()),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'TOOLS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _open(context, const RunCommissionPage()),
                  icon: const Icon(Icons.percent),
                  label: const Text('Run Commission'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _open(context, const AuthDebugPage()),
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Auth Debug'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _open(context, const WalletTopupApprovalPage()),
                  icon: const Icon(Icons.approval_outlined),
                  label: const Text('Topup Approval'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
