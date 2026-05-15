import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FraudDashboardPage extends StatefulWidget {
  const FraudDashboardPage({super.key});

  @override
  State<FraudDashboardPage> createState() => _FraudDashboardPageState();
}

class _FraudDashboardPageState extends State<FraudDashboardPage> {
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

  int _countStatus(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String status) {
    return docs.where((d) {
      final v = (d.data()['status'] ?? '').toString().toLowerCase().trim();
      return v == status;
    }).length;
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
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
                  fontSize: 24,
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
            width: 110,
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
        .collection('receipt_validation_logs')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud Dashboard'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: logsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ER dashboard: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          final validCount = _countStatus(docs, 'valid');
          final invalidCount = _countStatus(docs, 'invalid');
          final suspiciousCount = _countStatus(docs, 'suspicious');

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Row(
                children: [
                  _statCard('Valid', '$validCount', Icons.verified, Colors.green),
                  const SizedBox(width: 10),
                  _statCard('Invalid', '$invalidCount', Icons.cancel, Colors.red),
                  const SizedBox(width: 10),
                  _statCard('Suspicious', '$suspiciousCount', Icons.warning, Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Total logs: ${docs.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Pa gen validation log toujou'),
                  ),
                )
              else
                ...docs.map((doc) {
                  final d = doc.data();
                  final status = (d['status'] ?? '').toString().toLowerCase().trim();

                  Color badgeColor = Colors.grey;
                  if (status == 'valid') badgeColor = Colors.green;
                  if (status == 'invalid') badgeColor = Colors.red;
                  if (status == 'suspicious') badgeColor = Colors.orange;

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
                                  (d['txId'] ?? '').toString().isEmpty
                                      ? 'VALIDATION LOG'
                                      : 'TxId: ${(d['txId'] ?? '').toString()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: badgeColor),
                                ),
                                child: Text(
                                  status.isEmpty ? '-' : status.toUpperCase(),
                                  style: TextStyle(
                                    color: badgeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _line('Service', (d['serviceName'] ?? '').toString()),
                          _line('Customer', (d['customerName'] ?? '').toString()),
                          _line('Phone', (d['customerPhone'] ?? '').toString()),
                          _line('Amount', '${(d['paymentAmount'] ?? '').toString()} ${(d['paymentCurrency'] ?? '').toString()}'),
                          _line('Validated By', (d['validatedBy'] ?? '').toString()),
                          _line('Validated At', _fmtDate(d['createdAt'])),
                          _line('Reason', (d['reason'] ?? '').toString()),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
