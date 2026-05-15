import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateTransactionScreen extends StatefulWidget {
  const CreateTransactionScreen({super.key});

  @override
  State<CreateTransactionScreen> createState() =>
      _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends State<CreateTransactionScreen> {
  final clientCtrl = TextEditingController();
  final amountCtrl = TextEditingController();
  final feeCtrl = TextEditingController();

  String type = 'WU';
  bool loading = false;
  String msg = '';

  double _toDouble(String v) {
    return double.tryParse(v.trim()) ?? 0;
  }

  Future<String> _getEnterpriseId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final q = await FirebaseFirestore.instance
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw Exception('enterprise_users pa jwenn pou user sa a');
    }

    final enterpriseId =
        (q.docs.first.data()['enterpriseId'] ?? '').toString().trim();

    if (enterpriseId.isEmpty) {
      throw Exception('enterpriseId vid');
    }

    return enterpriseId;
  }

  Future<void> _saveTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => msg = 'User pa konekte');
      return;
    }

    final clientName = clientCtrl.text.trim();
    final paymentAmount = _toDouble(amountCtrl.text);
    final fee = _toDouble(feeCtrl.text);

    if (clientName.isEmpty) {
      setState(() => msg = 'Antre non kliyan an');
      return;
    }

    if (paymentAmount <= 0) {
      setState(() => msg = 'Antre yon amount valid');
      return;
    }

    setState(() {
      loading = true;
      msg = '';
    });

    try {
      final enterpriseId = await _getEnterpriseId();

      final txRef = await FirebaseFirestore.instance
          .collection('transactions')
          .add({
        'clientName': clientName,
        'paymentAmount': paymentAmount,
        'fee': fee,
        'type': type,
        'status': 'delivered',
        'paymentStatus': 'paid',
        'enterpriseId': enterpriseId,
        'staffUid': user.uid,
        'staffEmail': user.email ?? '',
        'commissionApplied': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await txRef.update({
        'txId': txRef.id,
      });

// auto commission retire; itilize Run Commission page ak Firestore doc id.

      clientCtrl.clear();
      amountCtrl.clear();
      feeCtrl.clear();

      setState(() {
        type = 'WU';
        msg = 'Transaction anrejistre + commission aplike';
      });
    } catch (e) {
      setState(() => msg = 'ER: $e');
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void dispose() {
    clientCtrl.dispose();
    amountCtrl.dispose();
    feeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Transaction'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: clientCtrl,
              decoration: const InputDecoration(
                labelText: 'Client Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Fee',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: type,
              items: const [
                DropdownMenuItem(value: 'WU', child: Text('WU')),
                DropdownMenuItem(value: 'MonCash', child: Text('MonCash')),
                DropdownMenuItem(value: 'NatCash', child: Text('NatCash')),
                DropdownMenuItem(value: 'CAM', child: Text('CAM')),
              ],
              onChanged: loading
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() => type = v);
                      }
                    },
              decoration: const InputDecoration(
                labelText: 'Type',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _saveTransaction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    loading ? 'Tanpri tann...' : 'Save Transaction',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (msg.isNotEmpty)
              Text(
                msg,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
