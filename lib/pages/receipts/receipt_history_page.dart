import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ReceiptHistoryPage extends StatefulWidget {
  const ReceiptHistoryPage({super.key});

  @override
  State<ReceiptHistoryPage> createState() => _ReceiptHistoryPageState();
}

class _ReceiptHistoryPageState extends State<ReceiptHistoryPage> {
  final _searchCtrl = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return <String, dynamic>{};
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data() ?? <String, dynamic>{};
  }

  bool _matchesDate(Timestamp? ts) {
    if (ts == null) return true;
    final d = ts.toDate();
    final now = DateTime.now();

    if (_filter == 'today') {
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }
    if (_filter == '7days') {
      return d.isAfter(now.subtract(const Duration(days: 7)));
    }
    if (_filter == '30days') {
      return d.isAfter(now.subtract(const Duration(days: 30)));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserDoc(),
      builder: (context, userSnap) {
        final userData = userSnap.data ?? <String, dynamic>{};
        final enterpriseName =
            (userData['enterpriseName'] ?? 'VOUPVAPCASH').toString();
        final enterpriseId = (userData['enterpriseId'] ?? '').toString();
        final role = (userData['role'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(title: const Text('Receipt History')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            enterpriseName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text('Role: $role'),
                          Text('EnterpriseId: $enterpriseId'),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Chche pa txId, service, kliyan, phone...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Today'),
                      selected: _filter == 'today',
                      onSelected: (_) => setState(() => _filter = 'today'),
                    ),
                    ChoiceChip(
                      label: const Text('7 Days'),
                      selected: _filter == '7days',
                      onSelected: (_) => setState(() => _filter = '7days'),
                    ),
                    ChoiceChip(
                      label: const Text('30 Days'),
                      selected: _filter == '30days',
                      onSelected: (_) => setState(() => _filter = '30days'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: uid.isEmpty
                      ? const Center(child: Text('User pa konekte.'))
                      : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('transactions')
                              .where('staffUid', isEqualTo: uid)
                              .orderBy('createdAt', descending: true)
                              .limit(100)
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snap.hasError) {
                              return Center(
                                  child: Text('Erreur: ${snap.error}'));
                            }

                            final q = _searchCtrl.text.trim().toLowerCase();
                            final docs = (snap.data?.docs ?? []).where((d) {
                              final m = d.data();
                              final txId =
                                  (m['txId'] ?? d.id).toString().toLowerCase();
                              final service = (m['serviceName'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final customerPhone = (m['customerPhone'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final beneficiaryPhone =
                                  (m['beneficiaryPhone'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              final note =
                                  (m['note'] ?? '').toString().toLowerCase();
                              final createdAt = m['createdAt'] as Timestamp?;

                              final textOk = q.isEmpty ||
                                  txId.contains(q) ||
                                  service.contains(q) ||
                                  customerPhone.contains(q) ||
                                  beneficiaryPhone.contains(q) ||
                                  note.contains(q);

                              return textOk && _matchesDate(createdAt);
                            }).toList();

                            if (docs.isEmpty) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Pa gen receipt ki jwenn'),
                                ),
                              );
                            }

                            return ListView.builder(
                              itemCount: docs.length,
                              itemBuilder: (context, i) {
                                final d = docs[i];
                                final m = d.data();
                                final txId = (m['txId'] ?? d.id).toString();
                                final service =
                                    (m['serviceName'] ?? '').toString();
                                final amount =
                                    (m['paymentAmount'] ?? 0).toString();
                                final customerPhone =
                                    (m['customerPhone'] ?? '').toString();
                                final beneficiaryPhone =
                                    (m['beneficiaryPhone'] ?? '').toString();
                                final status = (m['status'] ?? '').toString();

                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.receipt_long),
                                    title: Text(txId),
                                    subtitle: Text(
                                      '$service | $amount USD\n'
                                      'Customer: $customerPhone | Beneficiary: $beneficiaryPhone\n'
                                      'Status: $status',
                                    ),
                                    isThreeLine: true,
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
      },
    );
  }
}
