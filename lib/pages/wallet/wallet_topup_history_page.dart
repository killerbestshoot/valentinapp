import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletTopupHistoryPage extends StatefulWidget {
  const WalletTopupHistoryPage({super.key});

  @override
  State<WalletTopupHistoryPage> createState() => _WalletTopupHistoryPageState();
}

class _WalletTopupHistoryPageState extends State<WalletTopupHistoryPage> {
  String _filter = 'all';

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
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

  Future<Map<String, dynamic>> _getProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(user.uid).get();
    String role =
        (userDoc.data()?['role'] ?? '').toString().toLowerCase().trim();

    final entSnap = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (entSnap.docs.isEmpty) {
      throw Exception('enterprise_users pa jwenn');
    }

    final ent = entSnap.docs.first.data();

    if (role.isEmpty) {
      role = (ent['role'] ?? '').toString().toLowerCase().trim();
    }

    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': (ent['displayName'] ?? user.email ?? '').toString(),
      'role': role,
      'enterpriseId': (ent['enterpriseId'] ?? '').toString(),
      'enterpriseName': (ent['enterpriseName'] ?? '').toString(),
    };
  }

  bool _matchFilter(Map<String, dynamic> d) {
    final status = (d['status'] ?? '').toString().toLowerCase().trim();

    if (_filter == 'pending') return status == 'pending';
    if (_filter == 'approved') return status == 'approved';
    if (_filter == 'rejected') return status == 'rejected';
    return true;
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
            width: 150,
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
        title: const Text('Wallet Topup History'),
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
          final enterpriseName = (profile['enterpriseName'] ?? '').toString();

          final isOwner = role == 'owner';
          final isAdmin = role == 'administrator' || role == 'admin';

          if (!isOwner && !isAdmin) {
            return const Center(
              child: Text('Se owner/admin slman ki ka w paj sa a'),
            );
          }

          final stream = FirebaseFirestore.instance
              .collection('wallet_topup_requests')
              .where('enterpriseId', isEqualTo: enterpriseId)
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
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
                  final da = _parseDate(a.data()['createdAt']);
                  final db = _parseDate(b.data()['createdAt']);
                  return db.compareTo(da);
                });

              final filteredDocs = docs.where((doc) {
                return _matchFilter(doc.data());
              }).toList();

              int pendingCount = 0;
              int approvedCount = 0;
              int rejectedCount = 0;

              double pendingAmount = 0;
              double approvedAmount = 0;
              double rejectedAmount = 0;

              for (final doc in docs) {
                final d = doc.data();
                final status =
                    (d['status'] ?? '').toString().toLowerCase().trim();
                final amount = _toDouble(d['amount']);

                if (status == 'pending') {
                  pendingCount++;
                  pendingAmount += amount;
                } else if (status == 'approved') {
                  approvedCount++;
                  approvedAmount += amount;
                } else if (status == 'rejected') {
                  rejectedCount++;
                  rejectedAmount += amount;
                }
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
                            enterpriseName,
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
                  Row(
                    children: [
                      _statCard(
                        'Pending',
                        '$pendingCount',
                        Icons.pending_actions,
                        Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Approved',
                        '$approvedCount',
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Rejected',
                        '$rejectedCount',
                        Icons.cancel,
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard(
                        'Pending Amt',
                        _fmtMoney(pendingAmount),
                        Icons.schedule,
                        Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Approved Amt',
                        _fmtMoney(approvedAmount),
                        Icons.arrow_downward,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Rejected Amt',
                        _fmtMoney(rejectedAmount),
                        Icons.block,
                        Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('all', 'All'),
                        _chip('pending', 'Pending'),
                        _chip('approved', 'Approved'),
                        _chip('rejected', 'Rejected'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filteredDocs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child:
                            Text('Pa gen wallet topup history pou filt sa a'),
                      ),
                    )
                  else
                    ...filteredDocs.map((doc) {
                      final d = doc.data();
                      final status =
                          (d['status'] ?? '').toString().toLowerCase().trim();

                      Color statusColor = Colors.grey;
                      if (status == 'pending') statusColor = Colors.orange;
                      if (status == 'approved') statusColor = Colors.green;
                      if (status == 'rejected') statusColor = Colors.red;

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
                                      (d['targetName'] ?? '').toString().isEmpty
                                          ? 'TOPUP REQUEST'
                                          : (d['targetName'] ?? '').toString(),
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
                                      color: statusColor.withAlpha(30),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: statusColor),
                                    ),
                                    child: Text(
                                      status.isEmpty
                                          ? '-'
                                          : status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _line('Request ID', doc.id),
                              _line('Target UID',
                                  (d['targetUid'] ?? '').toString()),
                              _line('Target Name',
                                  (d['targetName'] ?? '').toString()),
                              _line('Target Email',
                                  (d['targetEmail'] ?? '').toString()),
                              _line('Target Role',
                                  (d['targetRole'] ?? '').toString()),
                              _line(
                                'Amount',
                                '${_fmtMoney(_toDouble(d['amount']))} ${(d['currency'] ?? 'USD').toString()}',
                              ),
                              _line('Requested By',
                                  (d['requestedByName'] ?? '').toString()),
                              _line('Requester Role',
                                  (d['requestedByRole'] ?? '').toString()),
                              _line('Note', (d['note'] ?? '').toString()),
                              _line(
                                'Wallet Before',
                                _fmtMoney(_toDouble(d['walletBalanceBefore'])),
                              ),
                              _line(
                                'Wallet After',
                                _fmtMoney(_toDouble(d['walletBalanceAfter'])),
                              ),
                              _line('Approved By',
                                  (d['approvedByName'] ?? '').toString()),
                              _line('Approved Role',
                                  (d['approvedByRole'] ?? '').toString()),
                              _line('Rejected By',
                                  (d['rejectedByName'] ?? '').toString()),
                              _line('Rejected Role',
                                  (d['rejectedByRole'] ?? '').toString()),
                              _line('Reject Note',
                                  (d['rejectNote'] ?? '').toString()),
                              _line('Created At', _fmtDate(d['createdAt'])),
                              _line('Approved At', _fmtDate(d['approvedAt'])),
                              _line('Rejected At', _fmtDate(d['rejectedAt'])),
                              _line('Updated At', _fmtDate(d['updatedAt'])),
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
