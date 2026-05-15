import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DailyClosingPage extends StatefulWidget {
  const DailyClosingPage({super.key});

  @override
  State<DailyClosingPage> createState() => _DailyClosingPageState();
}

class _DailyClosingPageState extends State<DailyClosingPage> {
  bool _closing = false;

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

  bool _isToday(dynamic value) {
    final d = _parseDate(value);
    if (d.millisecondsSinceEpoch == 0) return false;

    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _closeToday(Map<String, dynamic> profile) async {
    if (_closing) return;

    setState(() {
      _closing = true;
    });

    try {
      final db = FirebaseFirestore.instance;
      final enterpriseId = (profile['enterpriseId'] ?? '').toString();
      final enterpriseName = (profile['enterpriseName'] ?? '').toString();
      final staffUid = (profile['uid'] ?? '').toString();
      final staffName = (profile['displayName'] ?? '').toString();
      final role = (profile['role'] ?? '').toString();

      final dayKey = _todayKey();
      final closingId = '${enterpriseId}_$staffUid`_$dayKey';
      final closingRef = db.collection('daily_closings').doc(closingId);

      final existing = await closingRef.get();
      if (existing.exists) {
        throw Exception('Jounen sa deja fmen pou user sa');
      }

      final txSnap = await db
          .collection('transactions')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .where('staffUid', isEqualTo: staffUid)
          .get();

      final todayDocs = txSnap.docs.where((doc) {
        final data = doc.data();
        return _isToday(data['createdAt']);
      }).toList();

      num totalAmount = 0;
      num totalAgentCommission = 0;
      num totalOwnerCommission = 0;

      final Map<String, int> serviceCount = {};
      final Map<String, num> serviceAmount = {};

      for (final doc in todayDocs) {
        final d = doc.data();
        final amount = (d['paymentAmount'] as num?) ?? 0;
        final agentCommission = (d['commissionAgent'] as num?) ?? 0;
        final ownerCommission = (d['commissionOwner'] as num?) ?? 0;
        final serviceName = (d['serviceName'] ?? 'Unknown Service').toString();

        totalAmount += amount;
        totalAgentCommission += agentCommission;
        totalOwnerCommission += ownerCommission;

        serviceCount[serviceName] = (serviceCount[serviceName] ?? 0) + 1;
        serviceAmount[serviceName] = (serviceAmount[serviceName] ?? 0) + amount;
      }

      await closingRef.set({
        'closingId': closingId,
        'dayKey': dayKey,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'staffUid': staffUid,
        'staffName': staffName,
        'staffRole': role,
        'transactionCount': todayDocs.length,
        'totalAmount': totalAmount,
        'totalAgentCommission': totalAgentCommission,
        'totalOwnerCommission': totalOwnerCommission,
        'serviceCount': serviceCount,
        'serviceAmount': serviceAmount,
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedBy': staffUid,
        'closedByName': staffName,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily closing ft avk siks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER closing: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _closing = false;
        });
      }
    }
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

  Widget _line(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Closing'),
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
          final enterpriseId = (profile['enterpriseId'] ?? '').toString();
          final staffUid = (profile['uid'] ?? '').toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .where('staffUid', isEqualTo: staffUid)
                .snapshots(),
            builder: (context, txSnap) {
              if (txSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER TRANSACTIONS: ${txSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = txSnap.data!.docs.where((d) {
                final data = d.data();
                return _isToday(data['createdAt']);
              }).toList();

              num totalAmount = 0;
              num totalAgentCommission = 0;
              num totalOwnerCommission = 0;
              final Map<String, int> byService = {};

              for (final doc in docs) {
                final d = doc.data();
                final amount = (d['paymentAmount'] as num?) ?? 0;
                final agentCommission = (d['commissionAgent'] as num?) ?? 0;
                final ownerCommission = (d['commissionOwner'] as num?) ?? 0;
                final serviceName = (d['serviceName'] ?? 'Unknown Service').toString();

                totalAmount += amount;
                totalAgentCommission += agentCommission;
                totalOwnerCommission += ownerCommission;
                byService[serviceName] = (byService[serviceName] ?? 0) + 1;
              }

              final serviceEntries = byService.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

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
                          Text('Staff: ${(profile['displayName'] ?? '').toString()}'),
                          Text('Role: ${(profile['role'] ?? '').toString()}'),
                          Text('Day: ${_todayKey()}'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard(
                        'Transactions',
                        '${docs.length}',
                        Icons.receipt_long,
                        Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Sales',
                        _fmtMoney(totalAmount),
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard(
                        'Agent Comm.',
                        _fmtMoney(totalAgentCommission),
                        Icons.person,
                        Colors.teal,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Owner Comm.',
                        _fmtMoney(totalOwnerCommission),
                        Icons.admin_panel_settings,
                        Colors.deepPurple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Service Summary',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (serviceEntries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Pa gen tranzaksyon jodi a'),
                      ),
                    )
                  else
                    ...serviceEntries.map((e) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: _line(e.key, '${e.value} tx'),
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _closing ? null : () => _closeToday(profile),
                    icon: const Icon(Icons.lock_clock),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_closing ? 'Tanpri tann...' : 'CLOSE TODAY'),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}