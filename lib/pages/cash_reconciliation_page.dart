import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CashReconciliationPage extends StatefulWidget {
  const CashReconciliationPage({super.key});

  @override
  State<CashReconciliationPage> createState() => _CashReconciliationPageState();
}

class _CashReconciliationPageState extends State<CashReconciliationPage> {
  final TextEditingController _cashCountedCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  bool _saving = false;

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

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

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

  Future<void> _saveReconciliation({
    required Map<String, dynamic> profile,
    required num totalSales,
    required int txCount,
  }) async {
    if (_saving) return;

    final counted = double.tryParse(_cashCountedCtrl.text.trim());
    if (counted == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antre cash counted la byen')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final db = FirebaseFirestore.instance;

      final enterpriseId = (profile['enterpriseId'] ?? '').toString();
      final enterpriseName = (profile['enterpriseName'] ?? '').toString();
      final uid = (profile['uid'] ?? '').toString();
      final name = (profile['displayName'] ?? '').toString();
      final role = (profile['role'] ?? '').toString();

      final expectedCash = totalSales;
      final difference = counted - expectedCash;
      final status = difference == 0
          ? 'balanced'
          : difference < 0
              ? 'shortage'
              : 'surplus';

      final docId = '${enterpriseId}_${uid}_${_todayKey()}';

      await db.collection('cash_reconciliations').doc(docId).set({
        'reconciliationId': docId,
        'dayKey': _todayKey(),
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'staffUid': uid,
        'staffName': name,
        'staffRole': role,
        'transactionCount': txCount,
        'totalSales': totalSales,
        'cashExpected': expectedCash,
        'cashCounted': counted,
        'difference': difference,
        'status': status,
        'notes': _notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cash reconciliation sove')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER reconciliation: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cashCountedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Reconciliation'),
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
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER TRANSACTIONS: ${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snap.data!.docs.where((d) {
                return _isToday(d.data()['createdAt']);
              }).toList();

              num totalSales = 0;
              for (final doc in docs) {
                totalSales += (doc.data()['paymentAmount'] as num?) ?? 0;
              }

              final expectedCash = totalSales;
              final counted = double.tryParse(_cashCountedCtrl.text.trim()) ?? 0;
              final difference = counted - expectedCash;

              Color diffColor = Colors.grey;
              String diffLabel = 'BALANCED';
              if (difference < 0) {
                diffColor = Colors.red;
                diffLabel = 'SHORTAGE';
              } else if (difference > 0) {
                diffColor = Colors.orange;
                diffLabel = 'SURPLUS';
              } else {
                diffColor = Colors.green;
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
                        _fmtMoney(totalSales),
                        Icons.attach_money,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard(
                        'Cash Expected',
                        _fmtMoney(expectedCash),
                        Icons.account_balance_wallet,
                        Colors.teal,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Cash Counted',
                        _fmtMoney(counted),
                        Icons.payments,
                        Colors.deepPurple,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _cashCountedCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Cash Counted',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Nt',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            diffLabel,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: diffColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _fmtMoney(difference),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: diffColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _saveReconciliation(
                              profile: profile,
                              totalSales: totalSales,
                              txCount: docs.length,
                            ),
                    icon: const Icon(Icons.save),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(_saving ? 'Tanpri tann...' : 'SAVE RECONCILIATION'),
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