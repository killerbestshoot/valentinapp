import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'transaction_details_page.dart';

class TransactionManagementPage extends StatelessWidget {
  const TransactionManagementPage({super.key});

  String _text(dynamic value, [String fallback = '-']) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _money(dynamic value) => _toDouble(value).toStringAsFixed(2);

  String _date(dynamic value) {
    final d = _toDate(value);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$mi';
  }

  Future<String> _enterpriseId() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception('User pa konekte.');
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .get();

    final userData = userSnap.data() ?? <String, dynamic>{};
    final enterpriseId = (userData['enterpriseId'] ?? '').toString();

    if (enterpriseId.isEmpty) {
      throw Exception('enterpriseId pa disponib.');
    }

    return enterpriseId;
  }

  Future<void> _updateStatus({
    required BuildContext context,
    required String docId,
    required String status,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('transactions').doc(docId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status mete: $status')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur status: $e')),
      );
    }
  }

  Future<void> _deleteTx({
    required BuildContext context,
    required String docId,
  }) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Efase tranzaksyon'),
            content: const Text('Eske ou vle efase tranzaksyon sa a?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Non'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Wi'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await FirebaseFirestore.instance.collection('transactions').doc(docId).delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tranzaksyon efase.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur efase: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Transaction Management',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<String>(
        future: _enterpriseId(),
        builder: (context, enterpriseSnap) {
          if (enterpriseSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (enterpriseSnap.hasError || !enterpriseSnap.hasData) {
            return Center(
              child: Text('Erreur enterprise: ${enterpriseSnap.error}'),
            );
          }

          final enterpriseId = enterpriseSnap.data!;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .snapshots(),
            builder: (context, txSnap) {
              if (txSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = [...(txSnap.data?.docs ?? [])];
              docs.sort((a, b) {
                final da = _toDate(a.data()['createdAt']);
                final db = _toDate(b.data()['createdAt']);
                return db.compareTo(da);
              });

              if (docs.isEmpty) {
                return const Center(
                  child: Text('Pa gen tranzaksyon pou jere kounye a.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final d = docs[index];
                  final m = d.data();
                  final tx = {
                    'txId': d.id,
                    ...m,
                  };

                  final serviceName = _text(m['serviceName'], 'Service');
                  final customerPhone = _text(m['customerPhone']);
                  final amount = _money(m['paymentAmount']);
                  final currency = _text(m['paymentCurrency'], 'USD');
                  final status = _text(m['status'], 'unknown');
                  final createdAt = _date(m['createdAt']);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFF3F4F6),
                              child: Icon(
                                Icons.receipt_long_outlined,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                serviceName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            Text(
                              '$amount $currency',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Tel: $customerPhone'),
                        const SizedBox(height: 4),
                        Text('Status: $status'),
                        const SizedBox(height: 4),
                        Text('Dat: $createdAt'),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailsPage(tx: tx),
                                  ),
                                );
                              },
                              child: const Text('Detay'),
                            ),
                            OutlinedButton(
                              onPressed: () => _updateStatus(
                                context: context,
                                docId: d.id,
                                status: 'delivered',
                              ),
                              child: const Text('Delivered'),
                            ),
                            OutlinedButton(
                              onPressed: () => _updateStatus(
                                context: context,
                                docId: d.id,
                                status: 'pending',
                              ),
                              child: const Text('Pending'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _deleteTx(
                                context: context,
                                docId: d.id,
                              ),
                              child: const Text('Efase'),
                            ),
                          ],
                        ),
                      ],
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