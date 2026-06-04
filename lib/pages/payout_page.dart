import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/dashboard_ui.dart';

class PayoutPage extends StatefulWidget {
  const PayoutPage({super.key});

  @override
  State<PayoutPage> createState() => _PayoutPageState();
}

class _PayoutPageState extends State<PayoutPage> {
  static const String enterpriseId = 'ENT-001';

  final TextEditingController amountCtrl = TextEditingController();
  String? selectedUserId;
  bool saving = false;
  String statusText = 'Status ap part isit la';

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  Future<void> submitRequest(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  ) async {
    if (saving) return;

    FocusScope.of(context).unfocus();

    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => statusText = 'Antre yon kantite ki valab');
      return;
    }

    if (selectedUserId == null || selectedUserId!.isEmpty) {
      setState(() => statusText = 'Chwazi yon user');
      return;
    }

    final selectedUser = users.firstWhere(
      (u) => u.id == selectedUserId,
      orElse: () => users.first,
    );

    final data = selectedUser.data();
    final uid = (data['uid'] ?? selectedUser.id).toString();
    final role = (data['role'] ?? 'agent').toString();
    final balance =
        (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0;

    if (amount > balance) {
      setState(() => statusText = 'Balance ensifizan');
      return;
    }

    setState(() {
      saving = true;
      statusText = 'Payout request ap anrejistre...';
    });

    try {
      final doc =
          await FirebaseFirestore.instance.collection('payout_requests').add({
        'enterpriseId': enterpriseId,
        'uid': uid,
        'targetUid': uid,
        'targetRole': role.toLowerCase(),
        'targetName': uid,
        'amount': amount,
        'currency': 'USD',
        'status': 'pending',
        'processed': false,
        'requestedBy': uid,
        'requestedByName': uid,
        'requestedByRole': role.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      amountCtrl.clear();
      setState(() {
        statusText = 'Payout request anrejistre. DocId: ${doc.id}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request anrejistre')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => statusText = 'Erreur: $e');
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
    final usersStream = FirebaseFirestore.instance
        .collection('balances')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .snapshots();

    return DashboardPage(
      title: 'Payout',
      children: [
        const DashboardHero(
          icon: Icons.payments_outlined,
          title: 'Payout',
          subtitle: 'Create payout requests from available wallet balances.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usersStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Erreur Firestore: ${snapshot.error}');
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = snapshot.data!.docs;
              if (users.isEmpty) {
                return const Center(child: Text('Pa gen balance docs'));
              }

              selectedUserId ??= users.first.id;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedUserId,
                    decoration: const InputDecoration(
                      labelText: 'Chwazi user',
                      border: OutlineInputBorder(),
                    ),
                    items: users.map((u) {
                      final data = u.data();
                      final uid = (data['uid'] ?? u.id).toString();
                      final role = (data['role'] ?? 'agent').toString();
                      final balance = (data['balance'] is num)
                          ? (data['balance'] as num).toDouble()
                          : 0.0;

                      return DropdownMenuItem<String>(
                        value: u.id,
                        child: Text(
                            '$uid ($role) - ${balance.toStringAsFixed(2)} USD'),
                      );
                    }).toList(),
                    onChanged: saving
                        ? null
                        : (value) {
                            setState(() {
                              selectedUserId = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: saving ? null : () => submitRequest(users),
                    icon: const Icon(Icons.send_outlined),
                    label: Text(saving ? 'Sending...' : 'Send Payout Request'),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: DashboardColors.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DashboardColors.border),
                    ),
                    child: Text(statusText),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
