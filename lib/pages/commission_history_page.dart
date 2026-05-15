import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommissionHistoryPage extends StatelessWidget {
  const CommissionHistoryPage({super.key});

  Future<Map<String, dynamic>> _loadSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Pa gen user konekte.');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('users/{uid} pa egziste pou session sa a.');
    }

    final data = userDoc.data()!;
    return {
      'uid': user.uid,
      'role': (data['role'] ?? '').toString(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
      'displayName': (data['displayName'] ?? data['fullName'] ?? '').toString(),
    };
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v.toString()) ?? 0;
  }

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission History'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadSession(),
        builder: (context, sessionSnap) {
          if (sessionSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (sessionSnap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Er session: ${sessionSnap.error}'),
            );
          }

          final session = sessionSnap.data!;
          final role = (session['role'] ?? '').toString().toLowerCase();
          final enterpriseId = (session['enterpriseId'] ?? '').toString();

          if (enterpriseId.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('enterpriseId manke sou users/{uid}.'),
            );
          }

          if (role != 'owner' && role != 'administrator') {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Se owner oswa administrator slman ki ka w Commission History.'),
            );
          }

          final stream = FirebaseFirestore.instance
              .collection('transactions')
              .where('enterpriseId', isEqualTo: enterpriseId)
              .where('commissionApplied', isEqualTo: true)
              .orderBy('createdAt', descending: true)
              .limit(100)
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Er Firestore: ${snap.error}\n\n'
                    'Si li mande index, deploy firestore.indexes.json lan epi tann index la fin build.',
                  ),
                );
              }

              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Pa gen commission ki deja aplike pou enterprise sa a.'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final m = d.data();

                  final txId = (m['txId'] ?? m['transactionId'] ?? d.id).toString();
                  final staffName = (m['staffName'] ?? '').toString();
                  final staffRole = (m['staffRole'] ?? '').toString();
                  final serviceName = (m['serviceName'] ?? '').toString();

                  final paymentAmount = _asDouble(m['paymentAmount']);
                  final commissionAgent = _asDouble(m['commissionAgent']);
                  final commissionOwner = _asDouble(m['commissionOwner']);
                  final agentAfter = _asDouble(m['agentBalanceAfter']);
                  final ownerAfter = _asDouble(m['ownerBalanceAfter']);

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            txId,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Service: $serviceName'),
                          Text('Staff: $staffName'),
                          Text('Role: $staffRole'),
                          Text('Amount: ${paymentAmount.toStringAsFixed(2)}'),
                          Text('Commission Agent: ${commissionAgent.toStringAsFixed(2)}'),
                          Text('Commission Owner: ${commissionOwner.toStringAsFixed(2)}'),
                          Text('Agent Balance After: ${agentAfter.toStringAsFixed(2)}'),
                          Text('Owner Balance After: ${ownerAfter.toStringAsFixed(2)}'),
                          Text('Applied At: ${_fmtDate(m['commissionAppliedAt'] ?? m['createdAt'])}'),
                          const SizedBox(height: 6),
                          SelectableText('Doc ID: ${d.id}'),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}