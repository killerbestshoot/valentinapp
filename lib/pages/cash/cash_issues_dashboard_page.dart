import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class CashIssuesDashboardPage extends StatefulWidget {
  const CashIssuesDashboardPage({super.key});

  @override
  State<CashIssuesDashboardPage> createState() =>
      _CashIssuesDashboardPageState();
}

class _CashIssuesDashboardPageState extends State<CashIssuesDashboardPage> {
  String _filter = 'pending';

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

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  bool _matchFilter(Map<String, dynamic> d) {
    final status = (d['status'] ?? '').toString().toLowerCase().trim();
    final reviewStatus =
        (d['reviewStatus'] ?? 'pending').toString().toLowerCase().trim();

    if (_filter == 'pending') {
      return status != 'balanced' && reviewStatus == 'pending';
    }
    if (_filter == 'approved') {
      return reviewStatus == 'approved';
    }
    if (_filter == 'rejected') {
      return reviewStatus == 'rejected';
    }
    if (_filter == 'shortage') {
      return status == 'shortage';
    }
    if (_filter == 'surplus') {
      return status == 'surplus';
    }
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

  Future<void> _reviewIssue({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required String action,
    required Map<String, dynamic> profile,
  }) async {
    final notesController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            action == 'approved' ? 'Approve Cash Issue' : 'Reject Cash Issue',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: notesController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Review Notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, ''),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, notesController.text.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    notesController.dispose();

    if (result == null) return;

    try {
      final db = FirebaseFirestore.instance;
      final logId = AppIds.walletLog(seed: 'cash_issue:${doc.id}:$action');
      final ledgerId = AppIds.ledger(seed: 'cash_issue:${doc.id}:$action');
      final logRef = db.collection('cash_issue_review_logs').doc(logId);
      final walletLedgerRef = db.collection('wallet_ledger').doc(ledgerId);

      await db.runTransaction((tx) async {
        final freshSnap = await tx.get(doc.reference);
        if (!freshSnap.exists) {
          throw Exception('Cash issue pa egziste ank');
        }

        final freshData = freshSnap.data() as Map<String, dynamic>;
        final currentReviewStatus = (freshData['reviewStatus'] ?? 'pending')
            .toString()
            .toLowerCase()
            .trim();

        if (currentReviewStatus != 'pending') {
          throw Exception('Cash issue sa a deja review');
        }

        final issueStatus =
            (freshData['status'] ?? '').toString().toLowerCase().trim();
        final staffUid = (freshData['staffUid'] ?? '').toString().trim();
        final staffName = (freshData['staffName'] ?? '').toString().trim();
        final staffRole = (freshData['staffRole'] ?? '').toString().trim();
        final difference = _toDouble(freshData['difference']).abs();

        double walletBefore = 0;
        double walletAfter = 0;
        String walletAction = 'none';
        bool walletChanged = false;

        if (action == 'approved' &&
            (issueStatus == 'shortage' || issueStatus == 'surplus')) {
          if (staffUid.isEmpty) {
            throw Exception('staffUid manke sou cash issue a');
          }

          final walletRef = db.collection('wallets').doc(staffUid);
          final walletSnap = await tx.get(walletRef);

          if (!walletSnap.exists) {
            throw Exception('Wallet pa egziste pou staff sa a');
          }

          final walletData = walletSnap.data() as Map<String, dynamic>;
          walletBefore = _toDouble(walletData['balance']);

          if (issueStatus == 'shortage') {
            if (walletBefore < difference) {
              throw Exception(
                'Wallet pa sifi pou shortage sa a ($walletBefore < $difference)',
              );
            }
            walletAfter = walletBefore - difference;
            walletAction = 'wallet_debit_shortage';
            walletChanged = true;
          } else if (issueStatus == 'surplus') {
            walletAfter = walletBefore + difference;
            walletAction = 'wallet_credit_surplus';
            walletChanged = true;
          }

          tx.update(walletRef, {
            'balance': walletAfter,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          tx.set(walletLedgerRef, {
            'ledgerId': ledgerId,
            'type': 'cash_issue_wallet_adjustment',
            'cashIssueId': doc.id,
            'enterpriseId': (profile['enterpriseId'] ?? '').toString(),
            'enterpriseName': (profile['enterpriseName'] ?? '').toString(),
            'uid': staffUid,
            'staffName': staffName,
            'staffRole': staffRole,
            'issueStatus': issueStatus,
            'action': walletAction,
            'amount': difference,
            'balanceBefore': walletBefore,
            'balanceAfter': walletAfter,
            'reviewedBy': (profile['uid'] ?? '').toString(),
            'reviewedByName': (profile['displayName'] ?? '').toString(),
            'reviewerRole': (profile['role'] ?? '').toString(),
            'reviewNotes': result,
            'dayKey': (freshData['dayKey'] ?? '').toString(),
            'transactionCount': (freshData['transactionCount'] ?? 0),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        tx.update(doc.reference, {
          'reviewStatus': action,
          'reviewedBy': (profile['uid'] ?? '').toString(),
          'reviewedByName': (profile['displayName'] ?? '').toString(),
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewNotes': result,
          'walletAction': walletAction,
          'walletBalanceBefore': walletBefore,
          'walletBalanceAfter': walletAfter,
          'walletLedgerWritten': walletChanged,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(logRef, {
          'logId': logId,
          'type': 'cash_issue_review',
          'action': action,
          'cashIssueId': doc.id,
          'enterpriseId': (profile['enterpriseId'] ?? '').toString(),
          'enterpriseName': (profile['enterpriseName'] ?? '').toString(),
          'reviewedBy': (profile['uid'] ?? '').toString(),
          'reviewedByName': (profile['displayName'] ?? '').toString(),
          'reviewerRole': (profile['role'] ?? '').toString(),
          'reviewNotes': result,
          'issueStatus': issueStatus,
          'staffUid': staffUid,
          'staffName': staffName,
          'staffRole': staffRole,
          'dayKey': (freshData['dayKey'] ?? '').toString(),
          'transactionCount': (freshData['transactionCount'] ?? 0),
          'totalSales': (freshData['totalSales'] ?? 0),
          'cashExpected': (freshData['cashExpected'] ?? 0),
          'cashCounted': (freshData['cashCounted'] ?? 0),
          'difference': (freshData['difference'] ?? 0),
          'walletAction': walletAction,
          'walletBalanceBefore': walletBefore,
          'walletBalanceAfter': walletAfter,
          'walletLedgerWritten': walletChanged,
          'sourceCreatedAt': freshData['createdAt'],
          'sourceUpdatedAt': freshData['updatedAt'],
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approved'
                ? 'Cash issue approved + wallet ledger saved'
                : 'Cash issue rejected',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER REVIEW: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Issues Dashboard'),
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
                  final dbv = _parseDate(
                      b.data()['updatedAt'] ?? b.data()['createdAt']);
                  return dbv.compareTo(da);
                });

              final filteredDocs = docs.where((doc) {
                return _matchFilter(doc.data());
              }).toList();

              int pendingCount = 0;
              int approvedCount = 0;
              int rejectedCount = 0;
              int shortageCount = 0;
              int surplusCount = 0;
              num totalMismatch = 0;

              for (final doc in docs) {
                final d = doc.data();
                final status =
                    (d['status'] ?? '').toString().toLowerCase().trim();
                final reviewStatus = (d['reviewStatus'] ?? 'pending')
                    .toString()
                    .toLowerCase()
                    .trim();
                final difference = (d['difference'] as num?) ?? 0;

                if (status == 'shortage') shortageCount++;
                if (status == 'surplus') surplusCount++;
                if (reviewStatus == 'pending' && status != 'balanced') {
                  pendingCount++;
                }
                if (reviewStatus == 'approved') approvedCount++;
                if (reviewStatus == 'rejected') rejectedCount++;

                if (status != 'balanced') {
                  totalMismatch += difference.abs();
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
                        'Shortage',
                        '$shortageCount',
                        Icons.trending_down,
                        Colors.red,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Surplus',
                        '$surplusCount',
                        Icons.trending_up,
                        Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Mismatch',
                        _fmtMoney(totalMismatch),
                        Icons.warning_amber,
                        Colors.deepPurple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('pending', 'Pending'),
                        _chip('approved', 'Approved'),
                        _chip('rejected', 'Rejected'),
                        _chip('shortage', 'Shortage'),
                        _chip('surplus', 'Surplus'),
                        _chip('all', 'All'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filteredDocs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Pa gen cash issue pou filt sa a'),
                      ),
                    )
                  else
                    ...filteredDocs.map((doc) {
                      final d = doc.data();
                      final status =
                          (d['status'] ?? '').toString().toLowerCase().trim();
                      final reviewStatus = (d['reviewStatus'] ?? 'pending')
                          .toString()
                          .toLowerCase()
                          .trim();

                      Color statusColor = Colors.grey;
                      if (status == 'shortage') statusColor = Colors.red;
                      if (status == 'surplus') statusColor = Colors.orange;
                      if (status == 'balanced') statusColor = Colors.green;

                      Color reviewColor = Colors.grey;
                      if (reviewStatus == 'approved') {
                        reviewColor = Colors.green;
                      }
                      if (reviewStatus == 'rejected') reviewColor = Colors.red;
                      if (reviewStatus == 'pending') {
                        reviewColor = Colors.orange;
                      }

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
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: reviewColor.withAlpha(30),
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
                              _line(
                                'Transactions',
                                (d['transactionCount'] ?? 0).toString(),
                              ),
                              _line(
                                'Sales',
                                _fmtMoney((d['totalSales'] as num?) ?? 0),
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
                              _line('Notes', (d['notes'] ?? '').toString()),
                              _line(
                                'Reviewed By',
                                (d['reviewedByName'] ?? '').toString(),
                              ),
                              _line(
                                'Review Notes',
                                (d['reviewNotes'] ?? '').toString(),
                              ),
                              _line(
                                'Wallet Action',
                                (d['walletAction'] ?? '').toString(),
                              ),
                              _line(
                                'Wallet Before',
                                _fmtMoney(_toDouble(d['walletBalanceBefore'])),
                              ),
                              _line(
                                'Wallet After',
                                _fmtMoney(_toDouble(d['walletBalanceAfter'])),
                              ),
                              _line(
                                'Updated At',
                                _fmtDate(d['updatedAt'] ?? d['createdAt']),
                              ),
                              if (reviewStatus == 'pending') ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _reviewIssue(
                                          context: context,
                                          doc: doc,
                                          action: 'approved',
                                          profile: profile,
                                        ),
                                        icon: const Icon(Icons.check),
                                        label: const Text('Approve'),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () => _reviewIssue(
                                          context: context,
                                          doc: doc,
                                          action: 'rejected',
                                          profile: profile,
                                        ),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
