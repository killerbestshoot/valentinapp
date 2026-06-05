import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailyClosingHistoryPage extends StatefulWidget {
  const DailyClosingHistoryPage({super.key});

  @override
  State<DailyClosingHistoryPage> createState() =>
      _DailyClosingHistoryPageState();
}

class _DailyClosingHistoryPageState extends State<DailyClosingHistoryPage> {
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
            width: 130,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Closing History'),
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
          final staffUid = (profile['uid'] ?? '').toString();

          final isOwner = role == 'owner';
          final isAdmin = role == 'administrator' || role == 'admin';

          final stream = (isOwner || isAdmin)
              ? FirebaseFirestore.instance
                  .collection('daily_closings')
                  .where('enterpriseId', isEqualTo: enterpriseId)
                  .snapshots()
              : FirebaseFirestore.instance
                  .collection('daily_closings')
                  .where('staffUid', isEqualTo: staffUid)
                  .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER HISTORY: ${snap.error}',
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
                  final da = _parseDate(a.data()['closedAt']);
                  final db = _parseDate(b.data()['closedAt']);
                  return db.compareTo(da);
                });

              if (docs.isEmpty) {
                return const Center(
                  child: Text('Pa gen daily closing toujou'),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final d = docs[index].data();

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Day: ${(d['dayKey'] ?? '').toString()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _line('Staff', (d['staffName'] ?? '').toString()),
                          _line('Role', (d['staffRole'] ?? '').toString()),
                          _line('Transactions',
                              (d['transactionCount'] ?? 0).toString()),
                          _line('Sales',
                              _fmtMoney((d['totalAmount'] as num?) ?? 0)),
                          _line(
                              'Agent Comm.',
                              _fmtMoney(
                                  (d['totalAgentCommission'] as num?) ?? 0)),
                          _line(
                              'Owner Comm.',
                              _fmtMoney(
                                  (d['totalOwnerCommission'] as num?) ?? 0)),
                          _line('Status', (d['status'] ?? '').toString()),
                          _line('Closed At', _fmtDate(d['closedAt'])),
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
