import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/dashboard_ui.dart';
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
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(docId)
          .update({
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
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(docId)
          .delete();

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

  Widget _txCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data();
    final tx = <String, dynamic>{
      'txId': d.id,
      ...m,
    };

    final serviceName = _text(m['serviceName'], 'Service');
    final customerPhone = _text(m['customerPhone']);
    final amount = _money(m['paymentAmount']);
    final currency = _text(m['paymentCurrency'], 'USD');
    final status = _text(m['status'], 'unknown');
    final createdAt = _date(m['createdAt']);

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: DashboardColors.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: DashboardColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  serviceName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: DashboardColors.ink,
                  ),
                ),
              ),
              Text(
                '$amount $currency',
                style: const TextStyle(
                  color: DashboardColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DashboardInfoRow(label: 'Phone', value: customerPhone),
          DashboardInfoRow(label: 'Status', value: status),
          DashboardInfoRow(label: 'Date', value: createdAt),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TransactionDetailsPage(tx: tx),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Detay'),
              ),
              OutlinedButton.icon(
                onPressed: () => _updateStatus(
                  context: context,
                  docId: d.id,
                  status: 'delivered',
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Delivered'),
              ),
              OutlinedButton.icon(
                onPressed: () => _updateStatus(
                  context: context,
                  docId: d.id,
                  status: 'pending',
                ),
                icon: const Icon(Icons.pending_actions),
                label: const Text('Pending'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _deleteTx(
                  context: context,
                  docId: d.id,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Efase'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Transaction management',
      children: [
        const DashboardHero(
          icon: Icons.manage_search_outlined,
          title: 'Transaction management',
          subtitle: 'Review, update, and remove enterprise transactions.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<String>(
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
                  return const DashboardPanel(
                    child: Text('Pa gen tranzaksyon pou jere kounye a.'),
                  );
                }

                return Column(
                  children: [
                    for (final d in docs) ...[
                      _txCard(context, d),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
