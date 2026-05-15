import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_transaction_page.dart';
import 'topup_page.dart';
import 'send_page.dart';
import 'recent_transactions_page.dart';
import 'settings_page.dart';

class AgentDashboard extends StatelessWidget {
  const AgentDashboard({super.key});

  double _d(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Widget _row(String left, String right) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left, style: const TextStyle(fontSize: 18)),
          Text(right, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _service(String name) {
    return OutlinedButton(
      onPressed: () {},
      child: Text(name),
    );
  }

  Widget _action(BuildContext context, IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final user = userSnap.data?.data() ?? {};
        final enterpriseId = (user['enterpriseId'] ?? '').toString();
        final name = (user['displayName'] ?? user['fullName'] ?? 'Agent').toString();
        final enterprise = (user['enterpriseName'] ?? 'VOUPVAPCASH').toString();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('balances').doc('${enterpriseId}_$uid').snapshots(),
          builder: (context, balSnap) {
            final solde = _d(balSnap.data?.data()?['balance']);

            return Scaffold(
              appBar: AppBar(
                title: const Text('Agent Dashboard'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: () => FirebaseAuth.instance.signOut(),
                  ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    subtitle: Text(enterprise),
                  ),
                  const SizedBox(height: 16),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _row('Solde', '${solde.toStringAsFixed(2)} USD'),
                          const Divider(),
                          _row('Topup', '2000 USD'),
                          const Divider(),
                          _row('COM', '450 USD'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),
const Text('Sevis', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _service('Moncash'),
                      _service('Natcash'),
                      _service('Minit Haiti'),
                      _service('Pappadap'),
                    ],
                  ),

                  const SizedBox(height: 18),
                  _action(context, Icons.add_circle_outline, 'Nouvo transaction', const CreateTransactionPage()),
                  _action(context, Icons.phone_android, 'Rechaje kont Topup ou', const TopupPage()),
                  _action(context, Icons.send, 'Send', const SendPage()),
                  ListTile(
                    leading: const Icon(Icons.credit_card),
                    title: const Text('Rechaje avek credit/debit cards ou dbit cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fonksyon kredi/debit card ap vini.')),
                      );
                    },
                  ),
                  _action(context, Icons.receipt_long, 'Retrouve tout fich transaction yo', const RecentTransactionsPage()),
                  _action(context, Icons.settings, 'Paramet', const SettingsPage()),
                ],
              ),
            );
          },
        );
      },
    );
  }
}