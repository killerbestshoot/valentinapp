import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ClosingReportsPage extends StatefulWidget {
  const ClosingReportsPage({super.key});

  @override
  State<ClosingReportsPage> createState() => _ClosingReportsPageState();
}

class _ClosingReportsPageState extends State<ClosingReportsPage> {
  String _period = 'daily';

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  DateTime _startDateForPeriod() {
    final now = DateTime.now();

    if (_period == 'daily') {
      return DateTime(now.year, now.month, now.day);
    }

    if (_period == 'weekly') {
      final weekday = now.weekday;
      final start = now.subtract(Duration(days: weekday - 1));
      return DateTime(start.year, start.month, start.day);
    }

    return DateTime(now.year, now.month, 1);
  }

  String _fmtDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Widget _summaryBox(String title, String value, IconData icon) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
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
                    fontSize: 18,
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
    final startDate = _startDateForPeriod();
    final startTs = Timestamp.fromDate(startDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Closing Reports'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Daily'),
                  selected: _period == 'daily',
                  onSelected: (_) => setState(() => _period = 'daily'),
                ),
                ChoiceChip(
                  label: const Text('Weekly'),
                  selected: _period == 'weekly',
                  onSelected: (_) => setState(() => _period = 'weekly'),
                ),
                ChoiceChip(
                  label: const Text('Monthly'),
                  selected: _period == 'monthly',
                  onSelected: (_) => setState(() => _period = 'monthly'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('transactions')
                    .where('createdAt', isGreaterThanOrEqualTo: startTs)
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

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('commission_logs')
                        .where('createdAt', isGreaterThanOrEqualTo: startTs)
                        .orderBy('createdAt', descending: true)
                        .limit(500)
                        .snapshots(),
                    builder: (context, commissionSnap) {
                      if (commissionSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (commissionSnap.hasError) {
                        return Center(
                          child: Text(
                              'Erreur commission: ${commissionSnap.error}'),
                        );
                      }

                      final commissionDocs = commissionSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('payout_requests')
                            .where('updatedAt', isGreaterThanOrEqualTo: startTs)
                            .orderBy('updatedAt', descending: true)
                            .limit(500)
                            .snapshots(),
                        builder: (context, payoutSnap) {
                          if (payoutSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (payoutSnap.hasError) {
                            return Center(
                              child: Text('Erreur payout: ${payoutSnap.error}'),
                            );
                          }

                          final payoutDocs = payoutSnap.data?.docs ?? [];

                          int totalTx = txDocs.length;
                          double totalVolume = 0;
                          double totalCommissionAgent = 0;
                          double totalCommissionOwner = 0;
                          double totalPayout = 0;

                          final Map<String, int> serviceMap = {};
                          final List<Map<String, dynamic>> recentActivity = [];

                          for (final d in txDocs) {
                            final m = d.data();
                            totalVolume += _asDouble(m['paymentAmount']);

                            final service =
                                (m['serviceName'] ?? 'unknown').toString();
                            serviceMap[service] =
                                (serviceMap[service] ?? 0) + 1;

                            recentActivity.add({
                              'type': 'transaction',
                              'title': (m['txId'] ?? d.id).toString(),
                              'subtitle':
                                  '$service | ${_asDouble(m['paymentAmount']).toStringAsFixed(2)} USD | ${(m['status'] ?? '')}',
                            });
                          }

                          for (final d in commissionDocs) {
                            final m = d.data();
                            totalCommissionAgent +=
                                _asDouble(m['commissionAgent']);
                            totalCommissionOwner +=
                                _asDouble(m['commissionOwner']);

                            recentActivity.add({
                              'type': 'commission',
                              'title': (m['txId'] ?? d.id).toString(),
                              'subtitle':
                                  'Agent: ${_asDouble(m['commissionAgent']).toStringAsFixed(2)} USD | Owner: ${_asDouble(m['commissionOwner']).toStringAsFixed(2)} USD',
                            });
                          }

                          for (final d in payoutDocs) {
                            final m = d.data();
                            final status =
                                (m['status'] ?? '').toString().toLowerCase();
                            if (status == 'approved') {
                              totalPayout += _asDouble(m['amount']);
                            }

                            recentActivity.add({
                              'type': 'payout',
                              'title':
                                  (m['serviceName'] ?? 'payout').toString(),
                              'subtitle':
                                  '${_asDouble(m['amount']).toStringAsFixed(2)} USD | $status',
                            });
                          }

                          final topServices = serviceMap.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value));

                          return SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Report from ${_fmtDate(startDate)} to ${_fmtDate(DateTime.now())}',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _summaryBox(
                                      'Total Transactions',
                                      '$totalTx',
                                      Icons.receipt_long,
                                    ),
                                    _summaryBox(
                                      'Total Volume',
                                      '${totalVolume.toStringAsFixed(2)} USD',
                                      Icons.attach_money,
                                    ),
                                    _summaryBox(
                                      'Agent Commission',
                                      '${totalCommissionAgent.toStringAsFixed(2)} USD',
                                      Icons.person,
                                    ),
                                    _summaryBox(
                                      'Owner Commission',
                                      '${totalCommissionOwner.toStringAsFixed(2)} USD',
                                      Icons.workspace_premium,
                                    ),
                                    _summaryBox(
                                      'Approved Payouts',
                                      '${totalPayout.toStringAsFixed(2)} USD',
                                      Icons.payments,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'TOP SERVICES',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (topServices.isEmpty)
                                  const Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child:
                                          Text('Pa gen services pou peryd sa.'),
                                    ),
                                  )
                                else
                                  ...topServices.take(10).map((e) {
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(Icons.bar_chart),
                                        title: Text(e.key),
                                        trailing: Text('${e.value} tx'),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 20),
                                const Text(
                                  'RECENT ACTIVITY',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (recentActivity.isEmpty)
                                  const Card(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child:
                                          Text('Pa gen aktivite pou peryd sa.'),
                                    ),
                                  )
                                else
                                  ...recentActivity.take(30).map((a) {
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(Icons.history),
                                        title: Text(a['title'].toString()),
                                        subtitle:
                                            Text(a['subtitle'].toString()),
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
