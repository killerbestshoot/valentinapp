import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/commission_service.dart';
import '../widgets/dashboard_ui.dart';

class RunCommissionPage extends StatefulWidget {
  const RunCommissionPage({super.key});

  @override
  State<RunCommissionPage> createState() => _RunCommissionPageState();
}

class _RunCommissionPageState extends State<RunCommissionPage> {
  final _txCtrl = TextEditingController();
  String _msg = '';

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final id = _txCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _msg = 'Mete Firestore transaction doc id a.');
      return;
    }

    try {
      await CommissionService.applyCommission(id);
      setState(() => _msg = 'Commission aplike avk siks.');
    } catch (e) {
      setState(() => _msg = 'Function error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return DashboardPage(
      title: 'Run Commission',
      children: [
        const DashboardHero(
          icon: Icons.percent_outlined,
          title: 'Run Commission',
          subtitle: 'Apply commission automation to a selected transaction.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('SESSION UID: $uid'),
              const SizedBox(height: 12),
              TextField(
                controller: _txCtrl,
                decoration: const InputDecoration(
                  labelText: 'Transaction Firestore doc id',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Apply Commission Now'),
              ),
              if (_msg.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_msg),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DashboardSectionTitle(title: 'Recent Transactions'),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .orderBy('createdAt', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snap.data!.docs;
                  return Column(
                    children: docs.map((d) {
                      final m = d.data();
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.receipt_long_outlined),
                        title: Text((m['txId'] ?? d.id).toString()),
                        subtitle: Text(
                          'service: ${(m['serviceName'] ?? '')} | '
                          'role: ${(m['staffRole'] ?? '')} | '
                          'amount: ${(m['paymentAmount'] ?? '')} | '
                          'applied: ${(m['commissionApplied'] ?? false)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            _txCtrl.text = d.id;
                            setState(() => _msg = 'Doc id chwazi: ${d.id}');
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
