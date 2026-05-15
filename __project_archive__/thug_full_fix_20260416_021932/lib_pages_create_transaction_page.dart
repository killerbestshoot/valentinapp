import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  final amountCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    amountCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> createTx() async {
    if (saving) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    final phone = phoneCtrl.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antre yon kantite ki valab')),
      );
      return;
    }

    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antre telefÃƒÂ²n kliyan an')),
      );
      return;
    }

    setState(() => saving = true);

    try {
      await FirebaseFirestore.instance.collection('transactions').add({
        'amount': amount,
        'customerPhone': phone,
        'status': 'delivered',
        'createdAt': FieldValue.serverTimestamp(),
        'enterpriseId': 'ENT-001',
        'staffUid': user.uid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction created')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: 'Customer Phone'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving ? null : createTx,
              child: Text(saving ? 'Saving...' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}