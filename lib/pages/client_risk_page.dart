import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClientRiskPage extends StatefulWidget {
  const ClientRiskPage({super.key});

  @override
  State<ClientRiskPage> createState() => _ClientRiskPageState();
}

class _ClientRiskPageState extends State<ClientRiskPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'blacklist':
        return Colors.red;
      case 'watchlist':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Future<void> _setStatus({
    required String phone,
    required String status,
    required String currentNote,
  }) async {
    final noteCtrl = TextEditingController(text: currentNote);

    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Set $status for $phone'),
          content: TextField(
            controller: noteCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason / Note',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, noteCtrl.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (note == null) return;

    await FirebaseFirestore.instance.collection('client_flags').doc(phone).set({
      'phone': phone,
      'status': status,
      'note': note,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$phone -> $status sove')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Risk Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Chche kliyan pa customerPhone...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .orderBy('createdAt', descending: true)
                    .limit(500)
                    .snapshots(),
                builder: (context, txSnap) {
                  if (txSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (txSnap.hasError) {
                    return Center(child: Text('Erreur tx: ${txSnap.error}'));
                  }

                  final txDocs = txSnap.data?.docs ?? [];
                  final Map<String, List<Map<String, dynamic>>> grouped = {};

                  for (final d in txDocs) {
                    final m = d.data();
                    final phone = (m['customerPhone'] ?? '').toString().trim();
                    if (phone.isEmpty) continue;
                    if (query.isNotEmpty &&
                        !phone.toLowerCase().contains(query)) {
                      continue;
                    }
                    grouped.putIfAbsent(phone, () => []);
                    grouped[phone]!.add(m);
                  }

                  final phones = grouped.keys.toList()..sort();

                  if (phones.isEmpty) {
                    return const Center(child: Text('Pa gen kliyan jwenn.'));
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('client_flags')
                        .snapshots(),
                    builder: (context, flagSnap) {
                      if (flagSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final flagDocs = flagSnap.data?.docs ?? [];
                      final Map<String, Map<String, dynamic>> flags = {
                        for (final d in flagDocs) d.id: d.data()
                      };

                      return ListView.builder(
                        itemCount: phones.length,
                        itemBuilder: (context, index) {
                          final phone = phones[index];
                          final txs = grouped[phone] ?? [];
                          final total = txs.fold<double>(
                            0,
                            (sum, t) => sum + _asDouble(t['paymentAmount']),
                          );

                          final flag = flags[phone] ?? <String, dynamic>{};
                          final status =
                              (flag['status'] ?? 'normal').toString();
                          final note = (flag['note'] ?? '').toString();

                          return Card(
                            child: ExpansionTile(
                              leading: Icon(
                                Icons.shield,
                                color: _statusColor(status),
                              ),
                              title: Text(phone),
                              subtitle: Text(
                                'Status: $status | ${txs.length} tx | ${total.toStringAsFixed(2)} USD',
                              ),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    note.isEmpty ? 'Note: -' : 'Note: $note',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _setStatus(
                                        phone: phone,
                                        status: 'normal',
                                        currentNote: note,
                                      ),
                                      child: const Text('Normal'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _setStatus(
                                        phone: phone,
                                        status: 'watchlist',
                                        currentNote: note,
                                      ),
                                      child: const Text('Watchlist'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => _setStatus(
                                        phone: phone,
                                        status: 'blacklist',
                                        currentNote: note,
                                      ),
                                      child: const Text('Blacklist'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...txs.take(10).map((t) {
                                  final service =
                                      (t['serviceName'] ?? '').toString();
                                  final amount =
                                      _asDouble(t['paymentAmount']);
                                  final statusTx =
                                      (t['status'] ?? '').toString();
                                  final beneficiary =
                                      (t['beneficiaryPhone'] ?? '').toString();

                                  return Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      border: Border.all(
                                          color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(Icons.receipt),
                                      title: Text(service),
                                      subtitle: Text(
                                        'Beneficiary: $beneficiary\nStatus: $statusTx',
                                      ),
                                      trailing: Text(
                                        '${amount.toStringAsFixed(2)} USD',
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
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