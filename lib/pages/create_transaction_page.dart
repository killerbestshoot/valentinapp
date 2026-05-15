import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  String serviceName = 'MonCash';
  String paymentCurrency = 'MXN';
  bool loading = false;

  double _num(String v) => double.tryParse(v.replaceAll(',', '.').trim()) ?? 0;

  Future<void> save() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final amount = _num(amountCtrl.text);

    if (name.isEmpty || phone.isEmpty || amount <= 0) {
      await showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text('Chan manke'),
          content: Text('Ranpli non, telefòn, ak montan.'),
        ),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final docRef = await FirebaseFirestore.instance.collection('transactions').add({
        'serviceName': serviceName,
        'customerName': name,
        'customerPhone': phone,
        'paymentAmount': amount,
        'paymentCurrency': paymentCurrency,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Transaction save ✅'),
          content: SelectableText('ID: ${docRef.id}'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      nameCtrl.clear();
      phoneCtrl.clear();
      amountCtrl.clear();
    } catch (e) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erreur ❌'),
          content: SelectableText(e.toString()),
        ),
      );
    }

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvo transaction'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: serviceName,
            items: const [
              DropdownMenuItem(value: 'MonCash', child: Text('MonCash')),
              DropdownMenuItem(value: 'NatCash', child: Text('NatCash')),
              DropdownMenuItem(value: 'Minit Haiti', child: Text('Minit Haiti')),
            ],
            onChanged: (v) => setState(() => serviceName = v ?? 'MonCash'),
          ),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Non kliyan')),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Telefòn')),
          TextField(controller: amountCtrl, decoration: const InputDecoration(labelText: 'Montan'), keyboardType: TextInputType.number),
          DropdownButtonFormField<String>(
            initialValue: paymentCurrency,
            items: const [
              DropdownMenuItem(value: 'MXN', child: Text('MXN')),
              DropdownMenuItem(value: 'USD', child: Text('USD')),
              DropdownMenuItem(value: 'DOP', child: Text('DOP')),
              DropdownMenuItem(value: 'CLP', child: Text('CLP')),
              DropdownMenuItem(value: 'BRL', child: Text('BRL')),
              DropdownMenuItem(value: 'HTG', child: Text('HTG')),
            ],
            onChanged: (v) => setState(() => paymentCurrency = v ?? 'MXN'),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            onPressed: loading ? null : save,
            child: Text(loading ? 'Ap save...' : 'Save'),
          ),
        ],
      ),
    );
  }
}
