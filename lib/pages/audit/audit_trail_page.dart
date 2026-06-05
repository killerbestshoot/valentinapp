import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() => _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage> {
  String _filter = 'all';

  String _fmtTs(dynamic ts) {
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

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Color _typeColor(String type) {
    if (type.contains('commission')) return Colors.green;
    if (type.contains('payout')) return Colors.red;
    if (type.contains('job')) return Colors.blue;
    return Colors.grey;
  }

  IconData _typeIcon(String type) {
    if (type.contains('commission')) return Icons.bolt;
    if (type.contains('payout')) return Icons.payments;
    if (type.contains('job')) return Icons.settings_suggest;
    return Icons.history;
  }

  bool _matchesFilter(String group) {
    if (_filter == 'all') return true;
    return _filter == group;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Trail'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                ChoiceChip(
                  label: const Text('Commission'),
                  selected: _filter == 'commission',
                  onSelected: (_) => setState(() => _filter = 'commission'),
                ),
                ChoiceChip(
                  label: const Text('Payout'),
                  selected: _filter == 'payout',
                  onSelected: (_) => setState(() => _filter = 'payout'),
                ),
                ChoiceChip(
                  label: const Text('Jobs'),
                  selected: _filter == 'jobs',
                  onSelected: (_) => setState(() => _filter = 'jobs'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('commission_logs')
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, commissionSnap) {
                if (commissionSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (commissionSnap.hasError) {
                  return Center(
                    child:
                        Text('Erreur commission_logs: ${commissionSnap.error}'),
                  );
                }

                final commissionDocs = commissionSnap.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('payout_logs')
                      .orderBy('createdAt', descending: true)
                      .limit(200)
                      .snapshots(),
                  builder: (context, payoutSnap) {
                    if (payoutSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (payoutSnap.hasError) {
                      return Center(
                        child: Text('Erreur payout_logs: ${payoutSnap.error}'),
                      );
                    }

                    final payoutDocs = payoutSnap.data?.docs ?? [];

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('job_logs')
                          .orderBy('createdAt', descending: true)
                          .limit(200)
                          .snapshots(),
                      builder: (context, jobSnap) {
                        if (jobSnap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (jobSnap.hasError) {
                          return Center(
                            child: Text('Erreur job_logs: ${jobSnap.error}'),
                          );
                        }

                        final jobDocs = jobSnap.data?.docs ?? [];
                        final items = <Map<String, dynamic>>[];

                        if (_matchesFilter('commission')) {
                          for (final d in commissionDocs) {
                            final m = d.data();
                            items.add({
                              'group': 'commission',
                              'type': (m['type'] ?? 'commission').toString(),
                              'title': (m['txId'] ?? d.id).toString(),
                              'subtitle':
                                  'Agent: ${_asDouble(m['commissionAgent']).toStringAsFixed(2)} USD | '
                                      'Owner: ${_asDouble(m['commissionOwner']).toStringAsFixed(2)} USD | '
                                      'Staff: ${(m['staffName'] ?? '')}',
                              'createdAt': m['createdAt'],
                            });
                          }
                        }

                        if (_matchesFilter('payout')) {
                          for (final d in payoutDocs) {
                            final m = d.data();
                            items.add({
                              'group': 'payout',
                              'type': (m['type'] ?? 'payout').toString(),
                              'title': (m['serviceName'] ?? d.id).toString(),
                              'subtitle':
                                  'Amount: ${_asDouble(m['amount']).toStringAsFixed(2)} USD | '
                                      'Enterprise: ${(m['enterpriseId'] ?? '')} | '
                                      'UID: ${(m['uid'] ?? '')}',
                              'createdAt': m['createdAt'],
                            });
                          }
                        }

                        if (_matchesFilter('jobs')) {
                          for (final d in jobDocs) {
                            final m = d.data();
                            items.add({
                              'group': 'jobs',
                              'type': (m['job'] ?? 'job').toString(),
                              'title': (m['job'] ?? d.id).toString(),
                              'subtitle': 'Mode: ${(m['mode'] ?? '')} | '
                                  'Scanned: ${(m['scanned'] ?? '')} | '
                                  'Applied: ${(m['applied'] ?? '')} | '
                                  'Skipped: ${(m['skipped'] ?? '')}',
                              'createdAt': m['createdAt'],
                            });
                          }
                        }

                        items.sort((a, b) {
                          final aa = a['createdAt'];
                          final bb = b['createdAt'];
                          if (aa is Timestamp && bb is Timestamp) {
                            return bb.toDate().compareTo(aa.toDate());
                          }
                          return 0;
                        });

                        if (items.isEmpty) {
                          return const Center(
                            child: Text('Pa gen audit data.'),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final type = (item['type'] ?? '').toString();

                            return Card(
                              child: ListTile(
                                leading: Icon(
                                  _typeIcon(type),
                                  color: _typeColor(type),
                                ),
                                title: Text(
                                  (item['title'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  '${(item['subtitle'] ?? '').toString()}\n${_fmtTs(item['createdAt'])}',
                                ),
                                isThreeLine: true,
                              ),
                            );
                          },
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
    );
  }
}
