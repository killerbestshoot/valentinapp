import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptPage extends StatelessWidget {
  final String transactionId;

  const ReceiptPage({
    super.key,
    required this.transactionId,
  });

  String _s(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('transactions')
        .doc(transactionId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resi transaction'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.get(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Erreur: ${snap.error}'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.data!.exists) {
            return const Center(child: Text('Transaction pa jwenn.'));
          }

          final m = snap.data!.data() as Map<String, dynamic>;

          final service = _s(m['serviceName']);
          final name = _s(m['customerName']);
          final phone = _s(m['customerPhone']);
          final amount = _s(m['paymentAmount']);
          final currency = _s(m['paymentCurrency']);
          final status = _s(m['status']);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(
                child: Text(
                  'VOUPVAPCASH',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              const Center(child: Text('RECEIPT / RESI')),
              const Divider(height: 40),

              _line('ID', transactionId),
              _line('Service', service),
              _line('Kliyan', name),
              _line('Telefòn', phone),
              _line('Montan', '$amount $currency'),
              _line('Status', status),

              const SizedBox(height: 30),
              const Center(
                child: Text(
                  'Mèsi paske ou itilize VOUPVAPCASH ✅',
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: SelectableText(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
