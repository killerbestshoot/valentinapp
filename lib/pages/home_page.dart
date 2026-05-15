import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'create_transaction_page.dart';
import 'receipt_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String _s(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VOUPVAPCASH DASHBOARD'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Column(
              children: [
                Text(
                  'APP CONNECTE ✅',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('Firebase + Flutter Web OK'),
              ],
            ),
          ),

          const SizedBox(height: 30),

          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text(
                'NOUVO TRANSACTION',
                style: TextStyle(fontSize: 18),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CreateTransactionPage(),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 30),

          const Text(
            'Dènye transactions',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .orderBy('createdAt', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('Erreur: ${snap.error}');
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return const Text('Pa gen transaction ankò.');
              }

              return Column(
                children: docs.map((d) {
                  final m = d.data() as Map<String, dynamic>;

                  final service = _s(m['serviceName']);
                  final name = _s(m['customerName']);
                  final phone = _s(m['customerPhone']);
                  final amount = _s(m['paymentAmount']);
                  final currency = _s(m['paymentCurrency']);
                  final status = _s(m['status']);

                  return Card(
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptPage(transactionId: d.id),
                          ),
                        );
                      },
                      leading: const Icon(Icons.receipt_long),
                      title: Text(
                        '$service • $amount $currency',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('$name\n$phone\nStatus: $status\nID: ${d.id}'),
                      isThreeLine: true,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
