import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/commission_service.dart';

class RunCommissionPage extends StatefulWidget {
  const RunCommissionPage({super.key});

  @override
  State<RunCommissionPage> createState() => _RunCommissionPageState();
}

class _RunCommissionPageState extends State<RunCommissionPage> {
  final _txCtrl = TextEditingController();
  String _msg = '';

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final id = _txCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _msg = 'Mete Firestore transaction doc id a.');
      return;
    }

    try {
      await CommissionService.applyCommission(id);
      setState(() => _msg = 'Commission aplike avk siks.');
    } catch (e) {
      setState(() => _msg = 'Function error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Run Commission')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('SESSION UID: $uid'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _txCtrl,
              decoration: const InputDecoration(
                labelText: 'Transaction Firestore doc id',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _apply,
                child: const Text('Apply Commission Now'),
              ),
            ),
            const SizedBox(height: 12),
            if (_msg.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_msg),
              ),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .orderBy('createdAt', descending: true)
                    .limit(20)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snap.data!.docs;
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final d = docs[i];
                      final m = d.data();
                      return Card(
                        child: ListTile(
                          title: Text((m['txId'] ?? d.id).toString()),
                          subtitle: Text(
                            'service: ${(m['serviceName'] ?? '')} | '
                            'role: ${(m['staffRole'] ?? '')} | '
                            'amount: ${(m['paymentAmount'] ?? '')} | '
                            'applied: ${(m['commissionApplied'] ?? false)}'
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            onPressed: () {
                              _txCtrl.text = d.id;
                              setState(() {
                                _msg = 'Doc id chwazi: ${d.id}';
                              });
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}