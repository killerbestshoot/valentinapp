import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OwnerAdminWalletDashboardPage extends StatefulWidget {
  const OwnerAdminWalletDashboardPage({super.key});

  @override
  State<OwnerAdminWalletDashboardPage> createState() =>
      _OwnerAdminWalletDashboardPageState();
}

class _OwnerAdminWalletDashboardPageState
    extends State<OwnerAdminWalletDashboardPage> {
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

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _smallEmpty(String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Dashboard'),
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
              child: Text('Se owner/admin slman ki ka w Wallet Dashboard'),
            );
          }

          final walletsStream = FirebaseFirestore.instance
              .collection('wallets')
              .where('enterpriseId', isEqualTo: enterpriseId)
              .snapshots();

          final ledgerStream = FirebaseFirestore.instance
              .collection('wallet_ledger')
              .where('enterpriseId', isEqualTo: enterpriseId)
              .snapshots();

          final withdrawStream = FirebaseFirestore.instance
              .collection('payout_requests')
              .where('enterpriseId', isEqualTo: enterpriseId)
              .where('type', isEqualTo: 'withdraw')
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: walletsStream,
            builder: (context, walletSnap) {
              if (walletSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER WALLETS: ${walletSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!walletSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: ledgerStream,
                builder: (context, ledgerSnap) {
                  if (ledgerSnap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'ER LEDGER: ${ledgerSnap.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!ledgerSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: withdrawStream,
                    builder: (context, withdrawSnap) {
                      if (withdrawSnap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'ER WITHDRAW: ${withdrawSnap.error}',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }

                      if (!withdrawSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final walletDocs = walletSnap.data!.docs.toList();
                      final ledgerDocs = ledgerSnap.data!.docs.toList();
                      final withdrawDocs = withdrawSnap.data!.docs.toList();

                      walletDocs.sort((a, b) {
                        final ba = _toDouble(a.data()['balance']);
                        final bb = _toDouble(b.data()['balance']);
                        return bb.compareTo(ba);
                      });

                      final latestLedger = ledgerDocs.toList()
                        ..sort((a, b) {
                          final da = _parseDate(a.data()['createdAt']);
                          final db = _parseDate(b.data()['createdAt']);
                          return db.compareTo(da);
                        });

                      final latestWithdraws = withdrawDocs.toList()
                        ..sort((a, b) {
                          final da = _parseDate(a.data()['createdAt']);
                          final db = _parseDate(b.data()['createdAt']);
                          return db.compareTo(da);
                        });

                      double totalWalletBalance = 0;
                      int totalWallets = walletDocs.length;
                      int positiveWallets = 0;
                      int zeroWallets = 0;

                      for (final doc in walletDocs) {
                        final balance = _toDouble(doc.data()['balance']);
                        totalWalletBalance += balance;
                        if (balance > 0) {
                          positiveWallets++;
                        } else {
                          zeroWallets++;
                        }
                      }

                      double totalTopup = 0;
                      double totalTransferIn = 0;
                      double totalTransferOut = 0;
                      int totalTopupCount = 0;
                      int totalTransferCount = 0;

                      for (final doc in ledgerDocs) {
                        final d = doc.data();
                        final action =
                            (d['action'] ?? '').toString().toLowerCase().trim();
                        final amount = _toDouble(d['amount']);

                        if (action == 'wallet_credit_topup') {
                          totalTopup += amount;
                          totalTopupCount++;
                        }

                        if (action == 'wallet_transfer_credit') {
                          totalTransferIn += amount;
                        }

                        if (action == 'wallet_transfer_debit') {
                          totalTransferOut += amount;
                          totalTransferCount++;
                        }
                      }

                      int pendingWithdraws = 0;
                      int approvedWithdraws = 0;
                      int rejectedWithdraws = 0;
                      double pendingWithdrawAmount = 0;

                      for (final doc in withdrawDocs) {
                        final d = doc.data();
                        final status =
                            (d['status'] ?? '').toString().toLowerCase().trim();
                        final amount = _toDouble(d['amount']);

                        if (status == 'pending') {
                          pendingWithdraws++;
                          pendingWithdrawAmount += amount;
                        } else if (status == 'approved') {
                          approvedWithdraws++;
                        } else if (status == 'rejected') {
                          rejectedWithdraws++;
                        }
                      }

                      final topWallets = walletDocs.take(5).toList();
                      final lastTopups = latestLedger
                          .where((e) =>
                              (e.data()['action'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .trim() ==
                              'wallet_credit_topup')
                          .take(5)
                          .toList();

                      final lastTransfers = FirebaseFirestore.instance
                          .collection('wallet_transfers')
                          .where('enterpriseId', isEqualTo: enterpriseId)
                          .snapshots();

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: lastTransfers,
                        builder: (context, transferSnap) {
                          if (transferSnap.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  'ER TRANSFERS: ${transferSnap.error}',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          if (!transferSnap.hasData) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          final transferDocs = transferSnap.data!.docs.toList()
                            ..sort((a, b) {
                              final da = _parseDate(a.data()['createdAt']);
                              final db = _parseDate(b.data()['createdAt']);
                              return db.compareTo(da);
                            });

                          final latestTransfers = transferDocs.take(5).toList();

                          return ListView(
                            padding: const EdgeInsets.all(12),
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    'Wallets',
                                    '$totalWallets',
                                    Icons.account_balance_wallet,
                                    Colors.blue,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Total Balance',
                                    _fmtMoney(totalWalletBalance),
                                    Icons.savings,
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Positive',
                                    '$positiveWallets',
                                    Icons.trending_up,
                                    Colors.orange,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statCard(
                                    'Topup Count',
                                    '$totalTopupCount',
                                    Icons.add_card,
                                    Colors.teal,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Transfer Count',
                                    '$totalTransferCount',
                                    Icons.swap_horiz,
                                    Colors.deepPurple,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Zero Wallets',
                                    '$zeroWallets',
                                    Icons.remove_circle_outline,
                                    Colors.grey,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statCard(
                                    'Topup Total',
                                    _fmtMoney(totalTopup),
                                    Icons.arrow_downward,
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Transfer In',
                                    _fmtMoney(totalTransferIn),
                                    Icons.call_received,
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Transfer Out',
                                    _fmtMoney(totalTransferOut),
                                    Icons.call_made,
                                    Colors.red,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _statCard(
                                    'Withdraw Pending',
                                    '$pendingWithdraws',
                                    Icons.pending_actions,
                                    Colors.orange,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Withdraw Approved',
                                    '$approvedWithdraws',
                                    Icons.check_circle,
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 10),
                                  _statCard(
                                    'Withdraw Rejected',
                                    '$rejectedWithdraws',
                                    Icons.cancel,
                                    Colors.red,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    'Pending Withdraw Amount: ${_fmtMoney(pendingWithdrawAmount)} USD',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              _sectionTitle('Top Wallets'),
                              if (topWallets.isEmpty)
                                _smallEmpty('Pa gen wallet ank')
                              else
                                ...topWallets.map((doc) {
                                  final d = doc.data();
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _line('UID', (d['uid'] ?? '').toString()),
                                          _line('Email', (d['email'] ?? '').toString()),
                                          _line('Role', (d['role'] ?? '').toString()),
                                          _line(
                                            'Balance',
                                            '${_fmtMoney(_toDouble(d['balance']))} USD',
                                          ),
                                          _line(
                                            'Updated At',
                                            _fmtDate(d['updatedAt']),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              _sectionTitle('Dnye Topup Yo'),
                              if (lastTopups.isEmpty)
                                _smallEmpty('Pa gen topup ank')
                              else
                                ...lastTopups.map((doc) {
                                  final d = doc.data();
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _line('Staff', (d['staffName'] ?? '').toString()),
                                          _line('Role', (d['staffRole'] ?? '').toString()),
                                          _line('Amount', _fmtMoney(_toDouble(d['amount']))),
                                          _line('Before', _fmtMoney(_toDouble(d['balanceBefore']))),
                                          _line('After', _fmtMoney(_toDouble(d['balanceAfter']))),
                                          _line('By', (d['reviewedByName'] ?? '').toString()),
                                          _line('Note', (d['reviewNotes'] ?? '').toString()),
                                          _line('Created At', _fmtDate(d['createdAt'])),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              _sectionTitle('Dnye Transfer Yo'),
                              if (latestTransfers.isEmpty)
                                _smallEmpty('Pa gen transfer ank')
                              else
                                ...latestTransfers.map((doc) {
                                  final d = doc.data();
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _line('Transfer ID', (d['transferId'] ?? '').toString()),
                                          _line('From', (d['fromName'] ?? '').toString()),
                                          _line('From Role', (d['fromRole'] ?? '').toString()),
                                          _line('To', (d['toName'] ?? '').toString()),
                                          _line('To Role', (d['toRole'] ?? '').toString()),
                                          _line('Amount', _fmtMoney(_toDouble(d['amount']))),
                                          _line('Note', (d['note'] ?? '').toString()),
                                          _line('Created At', _fmtDate(d['createdAt'])),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              _sectionTitle('Dnye Withdraw Yo'),
                              if (latestWithdraws.isEmpty)
                                _smallEmpty('Pa gen withdraw ank')
                              else
                                ...latestWithdraws.take(5).map((doc) {
                                  final d = doc.data();
                                  return Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _line('UID', (d['uid'] ?? '').toString()),
                                          _line('Email', (d['email'] ?? '').toString()),
                                          _line('Role', (d['role'] ?? '').toString()),
                                          _line('Amount', _fmtMoney(_toDouble(d['amount']))),
                                          _line('Status', (d['status'] ?? '').toString()),
                                          _line('Created At', _fmtDate(d['createdAt'])),
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