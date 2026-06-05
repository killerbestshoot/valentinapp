import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CashReconciliationAuditHistoryPage extends StatefulWidget {
  const CashReconciliationAuditHistoryPage({super.key});

  @override
  State<CashReconciliationAuditHistoryPage> createState() =>
      _CashReconciliationAuditHistoryPageState();
}

class _CashReconciliationAuditHistoryPageState
    extends State<CashReconciliationAuditHistoryPage> {
  String _filter = 'all';

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

  bool _matchFilter(String action) {
    if (_filter == 'all') return true;
    return action == _filter;
  }

  Widget _chip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() {
            _filter = value;
          });
        },
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Reconciliation Audit History'),
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
              child: Text('Se owner/admin slman ki ka w paj sa a'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('cash_reconciliation_audit_logs')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER AUDIT: ${snap.error}',
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
                  final da = _parseDate(a.data()['createdAt']);
                  final db = _parseDate(b.data()['createdAt']);
                  return db.compareTo(da);
                });

              final filteredDocs = docs.where((doc) {
                final action = (doc.data()['action'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                return _matchFilter(action);
              }).toList();

              int approveCount = 0;
              int rejectCount = 0;
              num totalDifference = 0;

              for (final doc in filteredDocs) {
                final d = doc.data();
                final action =
                    (d['action'] ?? '').toString().toLowerCase().trim();
                final difference = (d['difference'] as num?) ?? 0;

                totalDifference += difference.abs();

                if (action == 'review_approved') approveCount++;
                if (action == 'review_rejected') rejectCount++;
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (profile['enterpriseName'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('Role: $role'),
                          Text('EnterpriseId: $enterpriseId'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('all', 'All'),
                        _chip('review_approved', 'Approved'),
                        _chip('review_rejected', 'Rejected'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard(
                        'Approved',
                        '$approveCount',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Rejected',
                        '$rejectCount',
                        Icons.cancel,
                        Colors.red,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Logs',
                        '${filteredDocs.length}',
                        Icons.history,
                        Colors.blue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard(
                        'Mismatch Total',
                        _fmtMoney(totalDifference),
                        Icons.warning_amber,
                        Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox.shrink()),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (filteredDocs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Pa gen audit log pou filt sa a'),
                      ),
                    )
                  else
                    ...filteredDocs.map((doc) {
                      final d = doc.data();
                      final action =
                          (d['action'] ?? '').toString().toLowerCase().trim();
                      final after = (d['reviewStatusAfter'] ?? '')
                          .toString()
                          .toLowerCase()
                          .trim();

                      Color badgeColor = Colors.grey;
                      if (action == 'review_approved') {
                        badgeColor = Colors.green;
                      }
                      if (action == 'review_rejected') badgeColor = Colors.red;

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
                                      action.isEmpty
                                          ? '-'
                                          : action.toUpperCase(),
                                      style: TextStyle(
                                        color: badgeColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _line('Staff', (d['staffName'] ?? '').toString()),
                              _line('Role', (d['staffRole'] ?? '').toString()),
                              _line('Day Key', (d['dayKey'] ?? '').toString()),
                              _line('Status', (d['status'] ?? '').toString()),
                              _line(
                                'Review Before',
                                (d['reviewStatusBefore'] ?? '').toString(),
                              ),
                              _line(
                                'Review After',
                                after,
                              ),
                              _line(
                                'Cash Expected',
                                _fmtMoney((d['cashExpected'] as num?) ?? 0),
                              ),
                              _line(
                                'Cash Counted',
                                _fmtMoney((d['cashCounted'] as num?) ?? 0),
                              ),
                              _line(
                                'Difference',
                                _fmtMoney((d['difference'] as num?) ?? 0),
                              ),
                              _line('Actor', (d['actorName'] ?? '').toString()),
                              _line(
                                'Actor Role',
                                (d['actorRole'] ?? '').toString(),
                              ),
                              _line(
                                'Created At',
                                _fmtDate(d['createdAt']),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
