import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReprintAuditPage extends StatelessWidget {
  const ReprintAuditPage({super.key});

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

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logsStream = FirebaseFirestore.instance
        .collection('receipt_reprint_logs')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Reprint Audit'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: logsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ER audit: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('Pa gen reprint log toujou'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final d = docs[index].data();

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (d['txId'] ?? '').toString().isEmpty
                            ? 'REPRINT LOG'
                            : 'TxId: ${(d['txId'] ?? '').toString()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _line('Action', (d['action'] ?? '').toString()),
                      _line('Service', (d['serviceName'] ?? '').toString()),
                      _line('Customer', (d['customerName'] ?? '').toString()),
                      _line('Phone', (d['customerPhone'] ?? '').toString()),
                      _line('Amount', '${(d['paymentAmount'] ?? '').toString()} ${(d['paymentCurrency'] ?? '').toString()}'),
                      _line('Printed By', (d['printedByName'] ?? '').toString()),
                      _line('Role', (d['printedByRole'] ?? '').toString()),
                      _line('Enterprise', (d['enterpriseName'] ?? '').toString()),
                      _line('Date', _fmtDate(d['createdAt'])),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
