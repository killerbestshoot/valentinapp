// ignore_for_file: prefer_const_constructors

import "package:cloud_firestore/cloud_firestore.dart";
import "package:flutter/material.dart";

class WalletDashboardPage extends StatelessWidget {
  const WalletDashboardPage({super.key});

  static const String enterpriseId = "ENT-001";

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse("$value") ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection("balances")
        .where("enterpriseId", isEqualTo: enterpriseId)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Wallet Dashboard"),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Text("Er: ${snap.error}"),
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snap.data?.docs ?? [];

          double totalBalance = 0;
          for (final d in docs) {
            totalBalance += _asDouble(d.data()["balance"]);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "WALLET SUMMARY",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text("Enterprise ID: $enterpriseId"),
                      Text("Accounts: ${docs.length}"),
                      Text(
                        "Total Balance: ${totalBalance.toStringAsFixed(2)} USD",
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "Pa gen wallet/balance pou enterprise sa a.",
                    ),
                  ),
                ),
              ...docs.map((d) {
                final data = d.data();
                final balance = _asDouble(data["balance"]);
                final currency = (data["currency"] ?? "USD").toString();
                final uid = (data["uid"] ?? "-").toString();
                final role = (data["role"] ?? "-").toString();
                final name =
                    (data["displayName"] ?? data["name"] ?? "-").toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text("UID: $uid"),
                          Text("Role: $role"),
                          Text(
                            "Balance: ${balance.toStringAsFixed(2)} $currency",
                          ),
                          Text("Doc ID: ${d.id}"),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}