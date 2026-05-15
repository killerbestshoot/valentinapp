import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController _searchCtrl = TextEditingController();

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

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd $hh:$mi';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients Dashboard'),
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
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(child: Text('Erreur: ${snap.error}'));
                  }

                  final docs = snap.data?.docs ?? [];

                  final Map<String, List<Map<String, dynamic>>> grouped = {};

                  double grandTotal = 0;
                  int totalTx = 0;

                  for (final d in docs) {
                    final m = d.data();
                    final phone = (m['customerPhone'] ?? '').toString().trim();

                    if (phone.isEmpty) continue;
                    if (query.isNotEmpty && !phone.toLowerCase().contains(query)) {
                      continue;
                    }

                    grouped.putIfAbsent(phone, () => []);
                    grouped[phone]!.add({
                      ...m,
                      '__docId': d.id,
                    });

                    grandTotal += _asDouble(m['paymentAmount']);
                    totalTx++;
                  }

                  final clients = grouped.entries.map((entry) {
                    final phone = entry.key;
                    final txs = entry.value;

                    double total = 0;
                    Timestamp? latestTs;
                    final Set<String> services = {};

                    for (final t in txs) {
                      total += _asDouble(t['paymentAmount']);
                      final ts = t['createdAt'];
                      if (ts is Timestamp) {
                        if (latestTs == null || ts.toDate().isAfter(latestTs.toDate())) {
                          latestTs = ts;
                        }
                      }
                      final service = (t['serviceName'] ?? '').toString().trim();
                      if (service.isNotEmpty) {
                        services.add(service);
                      }
                    }

                    return {
                      'phone': phone,
                      'txs': txs,
                      'txCount': txs.length,
                      'total': total,
                      'latestTs': latestTs,
                      'services': services.toList(),
                    };
                  }).toList();

                  clients.sort((a, b) {
                    final aa = (a['total'] as double);
                    final bb = (b['total'] as double);
                    return bb.compareTo(aa);
                  });

                  final totalClients = clients.length;
                  final topClients = clients.take(5).toList();

                  if (clients.isEmpty) {
                    return const Center(
                      child: Text('Pa gen kliyan jwenn.'),
                    );
                  }

                  return ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            runSpacing: 12,
                            spacing: 12,
                            children: [
                              _summaryBox(
                                title: 'Clients',
                                value: '$totalClients',
                                icon: Icons.people,
                              ),
                              _summaryBox(
                                title: 'Transactions',
                                value: '$totalTx',
                                icon: Icons.receipt_long,
                              ),
                              _summaryBox(
                                title: 'Volume',
                                value: '${grandTotal.toStringAsFixed(2)} USD',
                                icon: Icons.attach_money,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'TOP CLIENTS',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...topClients.map((c) {
                        final phone = c['phone'] as String;
                        final total = c['total'] as double;
                        final txCount = c['txCount'] as int;
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.workspace_premium),
                            title: Text(phone),
                            subtitle: Text('$txCount tranzaksyon'),
                            trailing: Text('${total.toStringAsFixed(2)} USD'),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const Text(
                        'ALL CLIENTS',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...clients.map((c) {
                        final phone = c['phone'] as String;
                        final txs = c['txs'] as List<Map<String, dynamic>>;
                        final total = c['total'] as double;
                        final txCount = c['txCount'] as int;
                        final latestTs = c['latestTs'];
                        final services = c['services'] as List<dynamic>;

                        return Card(
                          child: ExpansionTile(
                            leading: const Icon(Icons.person),
                            title: Text(phone),
                            subtitle: Text(
                              '$txCount tranzaksyon | ${total.toStringAsFixed(2)} USD\n'
                              'Dnye aktivite: ${_fmtDate(latestTs)}',
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            children: [
                              if (services.isNotEmpty)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'Services: ${services.join(', ')}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ...txs.map((t) {
                                final txId = (t['txId'] ?? t['transactionId'] ?? t['__docId']).toString();
                                final service = (t['serviceName'] ?? 'manual_tx').toString();
                                final status = (t['status'] ?? '').toString();
                                final amount = _asDouble(t['paymentAmount']);
                                final beneficiaryPhone = (t['beneficiaryPhone'] ?? '').toString();
                                final staffName = (t['staffName'] ?? '').toString();
                                final staffRole = (t['staffRole'] ?? '').toString();
                                final createdAt = _fmtDate(t['createdAt']);
                                final note = (t['note'] ?? '').toString();

                                return Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(12),
                                    color: Colors.grey.shade50,
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.receipt),
                                    title: Text(txId),
                                    subtitle: Text(
                                      'Service: $service\n'
                                      'Amount: ${amount.toStringAsFixed(2)} USD\n'
                                      'Status: $status\n'
                                      'Beneficiary: $beneficiaryPhone\n'
                                      'Staff: $staffName ($staffRole)\n'
                                      'Date: $createdAt\n'
                                      'Note: $note',
                                    ),
                                    isThreeLine: false,
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}