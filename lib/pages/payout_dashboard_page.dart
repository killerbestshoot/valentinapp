import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PayoutDashboardPage extends StatelessWidget {
  const PayoutDashboardPage({super.key});

  Future<Map<String, String>> getCurrentUserMeta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final data = doc.data();
    if (data == null) throw Exception('User profile not found');

    return {
      'uid': user.uid,
      'role': (data['role'] ?? '').toString(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
    };
  }

  Widget buildStatCard({
    required String title,
    required String value,
    IconData? icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 28),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildDashboard(String enterpriseId) {
    final enterpriseStream = FirebaseFirestore.instance
        .collection('enterprises')
        .doc(enterpriseId)
        .snapshots();

    final payoutsStream = FirebaseFirestore.instance
        .collection('payout_requests')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .snapshots();

    return StreamBuilder(
      stream: enterpriseStream,
      builder: (context, enterpriseSnap) {
        if (!enterpriseSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final enterpriseData =
            (enterpriseSnap.data as DocumentSnapshot).data() as Map<String, dynamic>? ?? {};

        final balance = (enterpriseData['balance'] ?? 0).toString();

        return StreamBuilder(
          stream: payoutsStream,
          builder: (context, payoutSnap) {
            if (!payoutSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = (payoutSnap.data as QuerySnapshot).docs;

            int pending = 0;
            int approved = 0;
            int rejected = 0;

            for (var d in docs) {
              final status = (d['status'] ?? '').toString();
              if (status == 'pending') pending++;
              if (status == 'approved') approved++;
              if (status == 'rejected') rejected++;
            }

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                buildStatCard(
                  title: 'Balance',
                  value: '$balance USD',
                  icon: Icons.account_balance_wallet,
                ),
                buildStatCard(
                  title: 'Pending',
                  value: '$pending',
                  icon: Icons.hourglass_empty,
                ),
                buildStatCard(
                  title: 'Approved',
                  value: '$approved',
                  icon: Icons.check,
                ),
                buildStatCard(
                  title: 'Rejected',
                  value: '$rejected',
                  icon: Icons.close,
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Dashboard'),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: getCurrentUserMeta(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final enterpriseId = snapshot.data!['enterpriseId']!;
          return buildDashboard(enterpriseId);
        },
      ),
    );
  }
}

