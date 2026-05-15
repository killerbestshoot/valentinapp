import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OwnerLiveWalletDashboardPage extends StatelessWidget {
  const OwnerLiveWalletDashboardPage({super.key});

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

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  String _fmtDate(dynamic value) {
    DateTime? dt;

    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is String) {
      dt = DateTime.tryParse(value);
    }

    if (dt == null) return '-';

    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _getProfile(),
      builder: (context, profileSnap) {
        if (profileSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wallet Dashboard')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ER PROFILE: ${profileSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        if (!profileSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = profileSnap.data!;
        final role = (profile['role'] ?? '').toString().toLowerCase().trim();
        final enterpriseId = (profile['enterpriseId'] ?? '').toString();
        final enterpriseName = (profile['enterpriseName'] ?? '').toString();
        final ownerBalanceDocId = '${enterpriseId}_OWNER';

        if (role != 'owner') {
          return Scaffold(
            appBar: AppBar(title: const Text('Wallet Dashboard')),
            body: const Center(
              child: Text('Se owner slman ki ka w paj sa a'),
            ),
          );
        }

        final balanceStream = FirebaseFirestore.instance
            .collection('balances')
            .doc(ownerBalanceDocId)
            .snapshots();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: balanceStream,
          builder: (context, balanceSnap) {
            if (balanceSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Wallet Dashboard')),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER BALANCE: ${balanceSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }

            if (!balanceSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final doc = balanceSnap.data!;
            final data = doc.data() ?? <String, dynamic>{};

            final balance = _toDouble(data['balance']);
            final currency = (data['currency'] ?? 'USD').toString();
            final updatedAt = data['updatedAt'];
            final createdAt = data['createdAt'];
            final uid = (data['uid'] ?? '').toString();
            final savedRole = (data['role'] ?? '').toString();
            final enterpriseIdSaved = (data['enterpriseId'] ?? '').toString();

            return Scaffold(
              appBar: AppBar(
                title: const Text('Wallet Dashboard'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Dashboard la ap li live sou Firestore'),
                        ),
                      );
                    },
                  ),
                ],
              ),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet,
                                size: 64,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'OWNER LIVE WALLET DASHBOARD',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                enterpriseName,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            children: [
                              const Text(
                                'BALANCE OWNER',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '${_fmtMoney(balance)} $currency',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Sa ap sti live nan collection balances',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DETAY OWNER BALANCE',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _line('Doc ID', ownerBalanceDocId),
                              _line('Enterprise', enterpriseName),
                              _line('Enterprise ID', enterpriseId),
                              _line('Enterprise Saved', enterpriseIdSaved),
                              _line('UID Saved', uid),
                              _line('Role Saved', savedRole),
                              _line('Current Role', role),
                              _line('Currency', currency),
                              _line('Balance', _fmtMoney(balance)),
                              _line('Created At', _fmtDate(createdAt)),
                              _line('Updated At', _fmtDate(updatedAt)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (!doc.exists)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'ATANSYON: balances/$ownerBalanceDocId pa egziste. '
                              'Men ou te di balance owner a deja egziste. '
                              'Tcheke si docId a vrman ${enterpriseId}_OWNER',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}