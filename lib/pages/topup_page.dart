import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/dashboard_ui.dart';

class TopupPage extends StatefulWidget {
  const TopupPage({super.key});

  @override
  State<TopupPage> createState() => _TopupPageState();
}

class _TopupPageState extends State<TopupPage> {
  final _amountCtrl = TextEditingController();
  bool _loading = false;

  double _amount() {
    return double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
  }

  Future<void> _save() async {
    final amount = _amount();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete montan Topup la')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ou pa konekte')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final fs = FirebaseFirestore.instance;

      final userDoc = await fs.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};

      final enterpriseId = (userData['enterpriseId'] ?? '').toString();
      final staffName =
          (userData['name'] ?? userData['fullName'] ?? user.email ?? '')
              .toString();
      final staffRole = (userData['role'] ?? 'agent').toString();

      if (enterpriseId.isEmpty) {
        throw Exception('enterpriseId manke sou user la');
      }

      final balanceId = '${enterpriseId}_${user.uid}';
      final balanceRef = fs.collection('balances').doc(balanceId);
      final logRef = fs.collection('topup_recharges').doc();

      await fs.runTransaction((tx) async {
        final balSnap = await tx.get(balanceRef);
        final oldData = balSnap.data() ?? {};
        final oldTopup = double.tryParse(
                (oldData['topupBalance'] ?? oldData['topup'] ?? 0)
                    .toString()) ??
            0;
        final newTopup = oldTopup + amount;

        tx.set(
            balanceRef,
            {
              'enterpriseId': enterpriseId,
              'uid': user.uid,
              'staffUid': user.uid,
              'staffName': staffName,
              'staffRole': staffRole,
              'topupBalance': FieldValue.increment(amount),
              'topup': FieldValue.increment(amount),
              'topupAmount': FieldValue.increment(amount),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        tx.set(logRef, {
          'enterpriseId': enterpriseId,
          'uid': user.uid,
          'staffUid': user.uid,
          'staffName': staffName,
          'staffRole': staffRole,
          'amount': amount,
          'currency': 'USD',
          'type': 'topup_recharge',
          'balanceBefore': oldTopup,
          'balanceAfter': newTopup,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Topup ajoute sou kont lan')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ere: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Rechaje Topup',
      children: [
        const DashboardHero(
          icon: Icons.add_card_outlined,
          title: 'Rechaje Topup',
          subtitle: 'Ajoute balans topup sou kont aktif la.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Montan',
                  hintText: 'Egzanp: 1000',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loading ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: DashboardColors.brand,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_card),
                label:
                    Text(_loading ? 'Ap ajoute...' : 'Ajoute sou kont Topup'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
