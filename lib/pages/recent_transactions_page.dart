import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RecentTransactionsPage extends StatelessWidget {
  const RecentTransactionsPage({super.key});

  String money(v) {
    final n = double.tryParse((v ?? 0).toString()) ?? 0;
    return NumberFormat('#,##0.00').format(n);
  }

  String date(v) {
    if (v is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(v.toDate());
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Transactions')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, s) {

          if (s.hasError) {
            return Center(child: Text('ERROR: ${s.error}'));
          }

          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = s.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('Pa gen tranzaksyon'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final tx = docs[i].data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // TITLE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tx['serviceName'] ?? 'Service',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${money(tx['amount'] ?? tx['paymentAmount'])} ${tx['paymentCurrency'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text('Status: ${tx['status']}'),
                      Text('Client: ${tx['customerName'] ?? '-'}'),
                      Text('Phone: ${tx['customerPhone'] ?? '-'}'),
                      Text('Date: ${date(tx['createdAt'])}'),

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

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RecentTransactionsPage();
  }
}