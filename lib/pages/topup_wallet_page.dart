import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TopupWalletPage extends StatefulWidget {
  const TopupWalletPage({super.key});

  @override
  State<TopupWalletPage> createState() => _TopupWalletPageState();
}

class _TopupWalletPageState extends State<TopupWalletPage> {
  static const String enterpriseId = 'ENT-001';
  static const String enterpriseName = 'VOUPVAPCASH';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antre yon kantite ki valab')),
      );
      return;
    }

    if (selectedUserId == null || selectedUserId!.isEmpty) {
      setState(() => statusText = 'Chwazi yon user');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chwazi yon user')),
      );
      return;
    }

    final selectedUser = users.firstWhere(
      (u) => u.id == selectedUserId,
      orElse: () => users.first,
    );

    final data = selectedUser.data();
    final targetUid = (data['uid'] ?? selectedUser.id).toString();
    final targetRole = (data['role'] ?? 'agent').toString().toLowerCase();
    final targetName =
        (data['displayName'] ?? data['email'] ?? targetUid).toString();

    setState(() {
      saving = true;
      statusText = 'Request ap voye...';
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('wallet_topup_requests')
          .add({
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'uid': targetUid,
        'targetUid': targetUid,
        'targetRole': targetRole,
        'targetName': targetName,
        'amount': amount,
        'currency': 'USD',
        'status': 'pending',
        'processed': false,
        'requestedBy': 'owner-ui',
        'requestedByName': 'Owner UI',
        'requestedByRole': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      amountCtrl.clear();
      setState(() {
        statusText = 'Topup request anrejistre. DocId: ${doc.id}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request anrejistre pou VOUPVAPCASH')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        statusText = 'Erreur: $e';
      });
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

    return Scaffold(
      appBar: AppBar(title: const Text('Topup Wallet')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: usersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Erreur Firestore: ${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data!.docs;
          if (users.isEmpty) {
            return const Center(
              child: Text('Pa gen user/balance pou enterprise la'),
            );
          }

          selectedUserId ??= users.first.id;

          return ListView(
            padding: const EdgeInsets.all(16),
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
                  return DropdownMenuItem<String>(
                    value: u.id,
                    child: Text('$uid ($role)'),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : () => submitRequest(users),
                  child: Text(saving ? 'Sending...' : 'Send Request'),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(statusText),
              ),
            ],
          );
        },
      ),
    );
  }
}
