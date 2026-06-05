import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PayoutRequestsPage extends StatelessWidget {
  const PayoutRequestsPage({super.key});

  Future<String> getUserRole() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    return doc.data()?['role'] ?? 'agent';
  }

  Future<void> approve(String id) async {
    await FirebaseFirestore.instance
        .collection('payout_requests')
        .doc(id)
        .update({
      'status': 'approved',
      'processed': true,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> reject(String id) async {
    await FirebaseFirestore.instance
        .collection('payout_requests')
        .doc(id)
        .update({
      'status': 'rejected',
      'processed': true,
      'rejectedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: getUserRole(),
      builder: (context, roleSnap) {
        if (!roleSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = roleSnap.data!;

        return Scaffold(
          appBar: AppBar(title: Text('Payout Requests ($role)')),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('payout_requests')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];

                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Amount: ${d['amount']}'),
                          Text('Status: ${d['status']}'),
                          const SizedBox(height: 10),

                          //  ONLY ADMIN / OWNER SEE BUTTONS
                          if (role == 'owner' || role == 'administrator')
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => approve(d.id),
                                  child: const Text('APPROVE'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () => reject(d.id),
                                  child: const Text('REJECT'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
