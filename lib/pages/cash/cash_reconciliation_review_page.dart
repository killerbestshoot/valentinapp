import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CashReconciliationReviewPage extends StatefulWidget {
  const CashReconciliationReviewPage({super.key});

  @override
  State<CashReconciliationReviewPage> createState() =>
      _CashReconciliationReviewPageState();
}

class _CashReconciliationReviewPageState
    extends State<CashReconciliationReviewPage> {
  Future<Map<String, dynamic>> _getProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(user.uid).get();
    final entSnap = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (entSnap.docs.isEmpty) {
      throw Exception('Enterprise pa jwenn');
    }

    final ent = entSnap.docs.first.data();

    return {
      'uid': user.uid,
      'displayName': (userDoc.data()?['displayName'] ?? '').toString(),
      'role': (ent['role'] ?? '').toString().toLowerCase().trim(),
      'enterpriseId': (ent['enterpriseId'] ?? '').toString(),
      'enterpriseName': (ent['enterpriseName'] ?? '').toString(),
    };
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fmtDate(dynamic value) {
    final d = _parseDate(value);
    if (d.millisecondsSinceEpoch == 0) return '-';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  Future<void> _setDecision({
    required String docId,
    required String decision,
    required Map<String, dynamic> profile,
  }) async {
    try {
      final db = FirebaseFirestore.instance;

      await db.collection('cash_reconciliations').doc(docId).set({
        'reviewStatus': decision,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': (profile['uid'] ?? '').toString(),
        'reviewedByName': (profile['displayName'] ?? '').toString(),
        'reviewedByRole': (profile['role'] ?? '').toString(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review sove: $decision')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER review: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Reconciliation Review'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getProfile(),
        builder: (context, profileSnap) {
          if (profileSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ER PROFILE: ${profileSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!profileSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = profileSnap.data!;
          final role = (profile['role'] ?? '').toString();
          final enterpriseId = (profile['enterpriseId'] ?? '').toString();

          final isOwner = role == 'owner';
          final isAdmin = role == 'administrator' || role == 'admin';

          if (!isOwner && !isAdmin) {
            return const Center(
              child: Text('Se owner/admin slman ki ka review paj sa a'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('cash_reconciliations')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER DATA: ${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs.toList()
                ..sort((a, b) {
                  final da = _parseDate(
                      a.data()['updatedAt'] ?? a.data()['createdAt']);
                  final db = _parseDate(
                      b.data()['updatedAt'] ?? b.data()['createdAt']);
                  return db.compareTo(da);
                });

              if (docs.isEmpty) {
                return const Center(
                  child: Text('Pa gen cash reconciliation toujou'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data();

                  final status =
                      (d['status'] ?? '').toString().toLowerCase().trim();
                  final reviewStatus = (d['reviewStatus'] ?? 'pending')
                      .toString()
                      .toLowerCase()
                      .trim();

                  Color badgeColor = Colors.grey;
                  if (status == 'balanced') badgeColor = Colors.green;
                  if (status == 'shortage') badgeColor = Colors.red;
                  if (status == 'surplus') badgeColor = Colors.orange;

                  Color reviewColor = Colors.grey;
                  if (reviewStatus == 'approved') reviewColor = Colors.green;
                  if (reviewStatus == 'rejected') reviewColor = Colors.red;
                  if (reviewStatus == 'pending') reviewColor = Colors.orange;

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Day: ${(d['dayKey'] ?? '').toString()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: badgeColor),
                                ),
                                child: Text(
                                  status.isEmpty ? '-' : status.toUpperCase(),
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: reviewColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: reviewColor),
                            ),
                            child: Text(
                              'REVIEW: ${reviewStatus.toUpperCase()}',
                              style: TextStyle(
                                color: reviewColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _line('Staff', (d['staffName'] ?? '').toString()),
                          _line('Role', (d['staffRole'] ?? '').toString()),
                          _line('Transactions',
                              (d['transactionCount'] ?? 0).toString()),
                          _line('Sales',
                              _fmtMoney((d['totalSales'] as num?) ?? 0)),
                          _line('Cash Expected',
                              _fmtMoney((d['cashExpected'] as num?) ?? 0)),
                          _line('Cash Counted',
                              _fmtMoney((d['cashCounted'] as num?) ?? 0)),
                          _line('Difference',
                              _fmtMoney((d['difference'] as num?) ?? 0)),
                          _line('Notes', (d['notes'] ?? '').toString()),
                          _line('Created At', _fmtDate(d['createdAt'])),
                          _line('Reviewed By',
                              (d['reviewedByName'] ?? '').toString()),
                          _line('Reviewed At', _fmtDate(d['reviewedAt'])),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _setDecision(
                                    docId: doc.id,
                                    decision: 'approved',
                                    profile: profile,
                                  ),
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('APPROVE'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _setDecision(
                                    docId: doc.id,
                                    decision: 'rejected',
                                    profile: profile,
                                  ),
                                  icon: const Icon(Icons.cancel),
                                  label: const Text('REJECT'),
                                ),
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
          );
        },
      ),
    );
  }
}
