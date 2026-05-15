import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OwnerRecentTransactions extends StatelessWidget {
  final String enterpriseId;

  const OwnerRecentTransactions({
    super.key,
    required this.enterpriseId,
  });

  String _amount(Map<String, dynamic> data) {
    final value = data['paymentAmount'] ?? data['transferAmount'] ?? 0;
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (enterpriseId.trim().isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RECENT TRANSACTIONS',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text('Pa gen enterprise pou chaje tranzaksyon yo.'),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'RECENT TRANSACTIONS',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              )
            else if (docs.isEmpty)
              const Text('Pa gen tranzaksyon ank')
            else
              ...docs.map((d) {
                final data = d.data();

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text((data['serviceName'] ?? 'Transaction').toString()),
                    subtitle: Text((data['status'] ?? '').toString()),
                    trailing: Text(
                      _amount(data),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}