import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('transactions')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Reports')),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('ER: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          double totalAmount = 0;
          double totalProfit = 0;

          for (final doc in docs) {
            final d = doc.data() as Map<String, dynamic>;
            totalAmount +=
                (d['amount'] is num) ? (d['amount'] as num).toDouble() : 0;
            totalProfit +=
                (d['profit'] is num) ? (d['profit'] as num).toDouble() : 0;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Total Amount: $totalAmount',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Total Profit: $totalProfit',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: docs.isEmpty
                    ? const Center(child: Text('Pa gen tranzaksyon poko.'))
                    : ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, i) {
                          final d = docs[i].data() as Map<String, dynamic>;
                          final type = (d['type'] ?? '').toString();
                          final client = (d['clientName'] ?? '').toString();
                          final agentEmail = (d['agentEmail'] ?? '').toString();
                          final amount = (d['amount'] ?? 0).toString();
                          final fee = (d['fee'] ?? 0).toString();

                          return ListTile(
                            title: Text('$type  $client'),
                            subtitle: Text('Agent: $agentEmail'),
                            trailing: Text('$amount / $fee'),
                          );
                        },
                      ),
              )
            ],
          );
        },
      ),
    );
  }
}
