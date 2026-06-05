import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CommissionAuditLogPage extends StatelessWidget {
  final String enterpriseId;

  const CommissionAuditLogPage({
    super.key,
    required this.enterpriseId,
  });

  double _toDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String _money(dynamic v) => _toDouble(v).toStringAsFixed(2);

  String _date(dynamic v) {
    if (v is! Timestamp) return '-';
    final d = v.toDate();
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$mi';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(title: const Text('Commission Audit Log')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('commission_logs')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...(snap.data?.docs ?? [])];

          docs.sort((a, b) {
            final da = a.data()['createdAt'];
            final db = b.data()['createdAt'];
            if (da is Timestamp && db is Timestamp) {
              return db.toDate().compareTo(da.toDate());
            }
            return 0;
          });

          if (docs.isEmpty) {
            return const Center(child: Text('Pa gen commission log ank.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final m = docs[index].data();

              final txId = (m['txId'] ?? '').toString();
              final staffName = (m['staffName'] ?? '').toString();
              final serviceName = (m['serviceName'] ?? '').toString();
              final agent = _money(m['commissionAgent']);
              final owner = _money(m['commissionOwner']);
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
                    Text(
                      serviceName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Tx: $txId'),
                    Text('Agent: $staffName'),
                    Text('Agent commission: $agent USD'),
                    Text('Owner commission: $owner USD'),
                    Text('Dat: $createdAt'),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
