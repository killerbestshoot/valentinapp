import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReceiptPreviewPage extends StatelessWidget {
  final String transactionDocId;

  const ReceiptPreviewPage({
    super.key,
    required this.transactionDocId,
  });

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd $hh:$mi';
    }
    return '-';
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('transactions')
          .doc(transactionDocId)
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snap.hasData || !snap.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Receipt Preview')),
            body: const Center(child: Text('Receipt pa jwenn.')),
          );
        }

        final m = snap.data!.data() ?? <String, dynamic>{};
        final txId = (m['txId'] ?? transactionDocId).toString();
        final serviceName = (m['serviceName'] ?? '').toString();
        final enterpriseName =
            (m['enterpriseName'] ?? 'VOUPVAPCASH').toString();
        final enterpriseId = (m['enterpriseId'] ?? '').toString();
        final customerPhone = (m['customerPhone'] ?? '').toString();
        final beneficiaryName = (m['beneficiaryName'] ?? '').toString();
        final beneficiaryPhone = (m['beneficiaryPhone'] ?? '').toString();
        final staffName = (m['staffName'] ?? '').toString();
        final amount = _asDouble(m['paymentAmount']);
        final paymentStatus = (m['paymentStatus'] ?? '').toString();
        final status = (m['status'] ?? '').toString();
        final note = (m['note'] ?? '').toString();
        final createdAt = _fmtTs(m['createdAt']);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Receipt Preview'),
            actions: [
              IconButton(
                icon: const Icon(Icons.print),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Print preview ready. Nou ka ajoute PDF apre sa.'),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Receipt preview pare pou share/export pita.'),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const Icon(Icons.receipt_long, size: 42),
                        const SizedBox(height: 12),
                        Text(
                          enterpriseName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Receipt / Resi',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const Divider(height: 28),
                        _line('Transaction ID', txId),
                        _line('Enterprise', enterpriseId),
                        _line('Service', serviceName),
                        _line('Customer Phone', customerPhone),
                        _line('Beneficiary Name', beneficiaryName),
                        _line('Beneficiary Phone', beneficiaryPhone),
                        _line('Agent', staffName),
                        _line('Amount', '${amount.toStringAsFixed(2)} USD'),
                        _line('Payment', paymentStatus),
                        _line('Status', status),
                        _line('Date', createdAt),
                        _line('Note', note.isEmpty ? '-' : note),
                        const Divider(height: 28),
                        const Text(
                          'Msi paske ou itilize VOUPVAPCASH',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dokiman sa a svi km prv Sevis la.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.print),
                            label: const Text('Print / Preview'),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Print preview ready. PDF ap vini nan pwochen etap la.'),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
