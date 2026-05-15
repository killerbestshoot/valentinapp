import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class LedgerPage extends StatelessWidget {
  const LedgerPage({super.key});

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .limit(200)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(child: Text('Erreur ledger: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Pa gen ledger data.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index];
              final m = d.data();

              final txId = (m['txId'] ?? d.id).toString();
              final service = (m['serviceName'] ?? '').toString();
              final amount = _asDouble(m['paymentAmount']);
              final status = (m['status'] ?? '').toString();
              final enterpriseId = (m['enterpriseId'] ?? '').toString();
              final staffName = (m['staffName'] ?? '').toString();

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(txId),
                  subtitle: Text(
                    'Service: $service\n'
                    'Amount: ${amount.toStringAsFixed(2)} USD\n'
                    'Status: $status\n'
                    'Enterprise: $enterpriseId\n'
                    'Staff: $staffName',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        },
      ),
    );
  }
}