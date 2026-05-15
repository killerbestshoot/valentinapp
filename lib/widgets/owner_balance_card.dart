import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class OwnerBalanceCard extends StatelessWidget {
  final String enterpriseId;
  final String enterpriseName;

  const OwnerBalanceCard({
    super.key,
    required this.enterpriseId,
    required this.enterpriseName,
  });

  double _num(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final docId = '${enterpriseId}_OWNER';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('balances')
          .doc(docId)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();

        final balance = _num(data?['balance']);
        final currency = (data?['currency'] ?? 'USD').toString();

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Icon(Icons.account_balance_wallet, size: 42),
                const SizedBox(height: 10),
                const Text(
                  'OWNER LIVE BALANCE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  enterpriseName,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // BALANCE
                Text(
                  '${balance.toStringAsFixed(2)} $currency',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                // DEBUG (IMPORTANT )
                if (!snap.hasData)
                  const Text(" Loading Firestore..."),

                if (snap.hasError)
                  Text(" Error: ${snap.error}"),

                if (data == null)
                  Text(" Doc pa jwenn: balances/$docId"),
              ],
            ),
          ),
        );
      },
    );
  }
}