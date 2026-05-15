import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WalletHistoryPage extends StatelessWidget {
  const WalletHistoryPage({super.key});

  static const String enterpriseId = 'ENT-001';

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _fmtTs(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('wallet_history')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erreur Firestore: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('Pa gen history pou kounye a'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final type = (data['type'] ?? '').toString();
              final targetName = (data['targetName'] ?? '').toString();
              final targetRole = (data['targetRole'] ?? '').toString();
              final amount = _asDouble(data['amount']);
              final before = _asDouble(data['balanceBefore']);
              final after = _asDouble(data['balanceAfter']);
              final requestedByName = (data['requestedByName'] ?? '').toString();
              final requestedByRole = (data['requestedByRole'] ?? '').toString();
              final date = _fmtTs(data['createdAt']);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$type - $targetName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Role: $targetRole'),
                      Text('Amount: ${amount.toStringAsFixed(2)} USD'),
                      Text('Before: ${before.toStringAsFixed(2)} USD'),
                      Text('After: ${after.toStringAsFixed(2)} USD'),
                      Text('Requested by: $requestedByName'),
                      Text('Requested by role: $requestedByRole'),
                      Text('Date: $date'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}