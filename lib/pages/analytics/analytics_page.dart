import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  final _searchCtrl = TextEditingController();
  String _filter = 'all';

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

  bool _matchDate(dynamic ts) {
    if (_filter == 'all') return true;
    if (ts is! Timestamp) return false;

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

  Widget _statBox({
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
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
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

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by service / agent / txId / enterprise...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                    return Center(
                        child: Text('Erreur analytics: ${snap.error}'));
                  }

                  final docs = (snap.data?.docs ?? []).where((d) {
                    final m = d.data();
                    final txId = (m['txId'] ?? d.id).toString().toLowerCase();
                    final service =
                        (m['serviceName'] ?? '').toString().toLowerCase();
                    final agent =
                        (m['staffName'] ?? '').toString().toLowerCase();
                    final enterprise =
                        (m['enterpriseId'] ?? '').toString().toLowerCase();
                    final createdAt = m['createdAt'];

                    final textOk = query.isEmpty ||
                        txId.contains(query) ||
                        service.contains(query) ||
                        agent.contains(query) ||
                        enterprise.contains(query);

                    return textOk && _matchDate(createdAt);
                  }).toList();

                  double totalVolume = 0;
                  int totalTx = docs.length;
                  int deliveredCount = 0;
                  int paidCount = 0;

                  final Map<String, double> serviceTotals = {};
                  final Map<String, int> serviceCounts = {};
                  final Map<String, double> agentTotals = {};
                  final Map<String, int> agentCounts = {};

                  for (final d in docs) {
                    final m = d.data();
                    final amount = _asDouble(m['paymentAmount']);
                    final service = (m['serviceName'] ?? 'unknown').toString();
                    final agent =
                        (m['staffName'] ?? 'Unknown Agent').toString();
                    final status = (m['status'] ?? '').toString().toLowerCase();
                    final paymentStatus =
                        (m['paymentStatus'] ?? '').toString().toLowerCase();

                    totalVolume += amount;
                    if (status == 'delivered') deliveredCount++;
                    if (paymentStatus == 'paid') paidCount++;

                    serviceTotals[service] =
                        (serviceTotals[service] ?? 0) + amount;
                    serviceCounts[service] = (serviceCounts[service] ?? 0) + 1;

                    agentTotals[agent] = (agentTotals[agent] ?? 0) + amount;
                    agentCounts[agent] = (agentCounts[agent] ?? 0) + 1;
                  }

                  final serviceRows = serviceTotals.keys.map((k) {
                    return {
                      'name': k,
                      'total': serviceTotals[k] ?? 0,
                      'count': serviceCounts[k] ?? 0,
                    };
                  }).toList()
                    ..sort((a, b) =>
                        (b['total'] as double).compareTo(a['total'] as double));

                  final agentRows = agentTotals.keys.map((k) {
                    return {
                      'name': k,
                      'total': agentTotals[k] ?? 0,
                      'count': agentCounts[k] ?? 0,
                    };
                  }).toList()
                    ..sort((a, b) =>
                        (b['total'] as double).compareTo(a['total'] as double));

                  return ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _statBox(
                                title: 'Transactions',
                                value: '$totalTx',
                                icon: Icons.receipt_long,
                              ),
                              _statBox(
                                title: 'Volume',
                                value: '${totalVolume.toStringAsFixed(2)} USD',
                                icon: Icons.attach_money,
                              ),
                              _statBox(
                                title: 'Delivered',
                                value: '$deliveredCount',
                                icon: Icons.check_circle_outline,
                              ),
                              _statBox(
                                title: 'Paid',
                                value: '$paidCount',
                                icon: Icons.payments_outlined,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'TOP SERVICES',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (serviceRows.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No service data found.'),
                          ),
                        )
                      else
                        ...serviceRows.take(10).map((row) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.miscellaneous_services),
                              title: Text(row['name'].toString()),
                              subtitle: Text('${row['count']} transactions'),
                              trailing: Text(
                                '${(row['total'] as double).toStringAsFixed(2)} USD',
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      const Text(
                        'TOP AGENTS',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (agentRows.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('No agent data found.'),
                          ),
                        )
                      else
                        ...agentRows.take(10).map((row) {
                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(row['name'].toString()),
                              subtitle: Text('${row['count']} transactions'),
                              trailing: Text(
                                '${(row['total'] as double).toStringAsFixed(2)} USD',
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 16),
                      const Text(
                        'LATEST TRANSACTIONS',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      if (docs.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child:
                                Text('No transaction found for this filter.'),
                          ),
                        )
                      else
                        ...docs.take(20).map((d) {
                          final m = d.data();
                          final txId = (m['txId'] ?? d.id).toString();
                          final service = (m['serviceName'] ?? '').toString();
                          final agent = (m['staffName'] ?? '').toString();
                          final amount = _asDouble(m['paymentAmount']);
                          final status = (m['status'] ?? '').toString();

                          return Card(
                            child: ListTile(
                              leading: const Icon(Icons.receipt),
                              title: Text(txId),
                              subtitle: Text('$service | $agent | $status'),
                              trailing:
                                  Text('${amount.toStringAsFixed(2)} USD'),
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
}
