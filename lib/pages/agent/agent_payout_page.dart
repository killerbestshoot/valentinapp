import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class AgentPayoutPage extends StatelessWidget {
  final String enterpriseId;

  const AgentPayoutPage({
    super.key,
    required this.enterpriseId,
  });

  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String _money(dynamic v) => _toDouble(v).toStringAsFixed(2);

  Future<void> _payAgent({
    required BuildContext context,
    required String balanceDocId,
    required String uid,
    required double currentBalance,
  }) async {
    final controller =
        TextEditingController(text: currentBalance.toStringAsFixed(2));

    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Peye agent'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Montant'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Anile'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim()) ?? 0;
              Navigator.of(context).pop(v);
            },
            child: const Text('Peye'),
          ),
        ],
      ),
    );

    if (amount == null || amount <= 0) return;

    try {
      final balanceRef =
          FirebaseFirestore.instance.collection('balances').doc(balanceDocId);
      final logId =
          AppIds.payoutLog(seed: 'agent:$balanceDocId:${DateTime.now()}');
      final logRef =
          FirebaseFirestore.instance.collection('payout_logs').doc(logId);

      await FirebaseFirestore.instance.runTransaction((trx) async {
        final snap = await trx.get(balanceRef);
        final data = snap.data() ?? <String, dynamic>{};
        final before = _toDouble(data['balance']);

        if (before < amount) {
          throw Exception('Balance pa sifi.');
        }

        final after = before - amount;

        trx.set(
            balanceRef,
            {
              'balance': after,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        trx.set(logRef, {
          'logId': logId,
          'enterpriseId': enterpriseId,
          'uid': uid,
          'balanceDocId': balanceDocId,
          'amount': amount,
          'currency': 'USD',
          'balanceBefore': before,
          'balanceAfter': after,
          'type': 'agent_payout',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payout ft: ${amount.toStringAsFixed(2)} USD')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur payout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Agent Payouts')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('balances')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .where('role', isEqualTo: 'agent')
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? [];

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (docs.isEmpty) {
            return const Center(child: Text('Pa gen agent balance ank.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final d = docs[index];
              final m = d.data();
              final uid = (m['uid'] ?? '').toString();
              final balance = _toDouble(m['balance']);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Color(0xFFF3F4F6),
                      child:
                          Icon(Icons.person_outline, color: Color(0xFF111827)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Agent\n$uid',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_money(balance)} USD',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        TextButton(
                          onPressed: balance <= 0
                              ? null
                              : () => _payAgent(
                                    context: context,
                                    balanceDocId: d.id,
                                    uid: uid,
                                    currentBalance: balance,
                                  ),
                          child: const Text('Peye'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
