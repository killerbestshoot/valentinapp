import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String _filter = 'all';

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

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

  Color _levelColor(String level) {
    switch (level) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      case 'info':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'critical':
        return Icons.warning_amber_rounded;
      case 'warning':
        return Icons.error_outline;
      case 'info':
        return Icons.notifications_active_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  bool _matchFilter(String level) {
    if (_filter == 'all') return true;
    return level == _filter;
  }

  Widget _statBox(String title, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cutoff7 = Timestamp.fromDate(now.subtract(const Duration(days: 7)));
    final cutoff30 = Timestamp.fromDate(now.subtract(const Duration(days: 30)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications + Alerts Center'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
                  label: const Text('Critical'),
                  selected: _filter == 'critical',
                  onSelected: (_) => setState(() => _filter = 'critical'),
                ),
                ChoiceChip(
                  label: const Text('Warning'),
                  selected: _filter == 'warning',
                  onSelected: (_) => setState(() => _filter = 'warning'),
                ),
                ChoiceChip(
                  label: const Text('Info'),
                  selected: _filter == 'info',
                  onSelected: (_) => setState(() => _filter = 'info'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('payout_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, payoutSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('services')
                        .where('active', isEqualTo: false)
                        .snapshots(),
                    builder: (context, serviceSnap) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('isActive', isEqualTo: false)
                            .snapshots(),
                        builder: (context, userSnap) {
                          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('transactions')
                                .orderBy('createdAt', descending: true)
                                .limit(300)
                                .snapshots(),
                            builder: (context, txSnap) {
                              if (payoutSnap.connectionState == ConnectionState.waiting ||
                                  serviceSnap.connectionState == ConnectionState.waiting ||
                                  userSnap.connectionState == ConnectionState.waiting ||
                                  txSnap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }

                              if (payoutSnap.hasError) {
                                return Center(child: Text('Erreur payouts: ${payoutSnap.error}'));
                              }
                              if (serviceSnap.hasError) {
                                return Center(child: Text('Erreur services: ${serviceSnap.error}'));
                              }
                              if (userSnap.hasError) {
                                return Center(child: Text('Erreur users: ${userSnap.error}'));
                              }
                              if (txSnap.hasError) {
                                return Center(child: Text('Erreur transactions: ${txSnap.error}'));
                              }

                              final List<Map<String, dynamic>> alerts = [];

                              final payoutDocs = payoutSnap.data?.docs ?? [];
                              for (final d in payoutDocs) {
                                final m = d.data();
                                final amount = _asDouble(m['amount']);
                                final serviceName = (m['serviceName'] ?? '').toString();
                                final uid = (m['uid'] ?? '').toString();

                                alerts.add({
                                  'level': amount >= 1000 ? 'critical' : 'warning',
                                  'title': 'Pending payout request',
                                  'subtitle': 'Service: $serviceName | UID: $uid',
                                  'value': '${amount.toStringAsFixed(2)} USD',
                                  'time': _fmtTs(m['createdAt']),
                                  'icon': Icons.payments_outlined,
                                });
                              }

                              final inactiveServiceDocs = serviceSnap.data?.docs ?? [];
                              for (final d in inactiveServiceDocs) {
                                final m = d.data();
                                final name = (m['name'] ?? d.id).toString();
                                final category = (m['category'] ?? '').toString();
                                final enterpriseId = (m['enterpriseId'] ?? '').toString();

                                alerts.add({
                                  'level': 'warning',
                                  'title': 'Inactive service',
                                  'subtitle': '$name | $category | Enterprise: $enterpriseId',
                                  'value': 'inactive',
                                  'time': _fmtTs(m['updatedAt']),
                                  'icon': Icons.block,
                                });
                              }

                              final inactiveUserDocs = userSnap.data?.docs ?? [];
                              for (final d in inactiveUserDocs) {
                                final m = d.data();
                                final name = (m['displayName'] ?? m['fullName'] ?? 'User').toString();
                                final role = (m['role'] ?? '').toString();
                                final enterpriseId = (m['enterpriseId'] ?? '').toString();

                                alerts.add({
                                  'level': 'warning',
                                  'title': 'Inactive user',
                                  'subtitle': '$name | $role | Enterprise: $enterpriseId',
                                  'value': d.id,
                                  'time': _fmtTs(m['updatedAt']),
                                  'icon': Icons.person_off,
                                });
                              }

                              final txDocs = txSnap.data?.docs ?? [];
                              for (final d in txDocs) {
                                final m = d.data();
                                final txId = (m['txId'] ?? d.id).toString();
                                final service = (m['serviceName'] ?? '').toString();
                                final staff = (m['staffName'] ?? '').toString();
                                final amount = _asDouble(m['paymentAmount']);
                                final status = (m['status'] ?? '').toString().toLowerCase();
                                final paymentStatus = (m['paymentStatus'] ?? '').toString().toLowerCase();
                                final createdAt = m['createdAt'];

                                if (status == 'failed') {
                                  alerts.add({
                                    'level': 'critical',
                                    'title': 'Transaction failed',
                                    'subtitle': '$txId | $service | $staff',
                                    'value': '${amount.toStringAsFixed(2)} USD',
                                    'time': _fmtTs(createdAt),
                                    'icon': Icons.error,
                                  });
                                }

                                if (paymentStatus == 'failed') {
                                  alerts.add({
                                    'level': 'critical',
                                    'title': 'Payment failed',
                                    'subtitle': '$txId | $service | $staff',
                                    'value': '${amount.toStringAsFixed(2)} USD',
                                    'time': _fmtTs(createdAt),
                                    'icon': Icons.money_off,
                                  });
                                }

                                if (status == 'pending') {
                                  alerts.add({
                                    'level': 'warning',
                                    'title': 'Transaction pending',
                                    'subtitle': '$txId | $service | $staff',
                                    'value': '${amount.toStringAsFixed(2)} USD',
                                    'time': _fmtTs(createdAt),
                                    'icon': Icons.hourglass_bottom,
                                  });
                                }

                                if (paymentStatus == 'pending') {
                                  alerts.add({
                                    'level': 'warning',
                                    'title': 'Payment pending',
                                    'subtitle': '$txId | $service | $staff',
                                    'value': '${amount.toStringAsFixed(2)} USD',
                                    'time': _fmtTs(createdAt),
                                    'icon': Icons.schedule,
                                  });
                                }

                                final commissionApplied = m['commissionApplied'] == true;
                                if (status == 'delivered' &&
                                    paymentStatus == 'paid' &&
                                    !commissionApplied &&
                                    createdAt is Timestamp &&
                                    createdAt.compareTo(cutoff7) < 0) {
                                  alerts.add({
                                    'level': 'info',
                                    'title': 'Commission not applied',
                                    'subtitle': '$txId | $service | $staff',
                                    'value': '${amount.toStringAsFixed(2)} USD',
                                    'time': _fmtTs(createdAt),
                                    'icon': Icons.percent,
                                  });
                                }

                                if (createdAt is Timestamp &&
                                    createdAt.compareTo(cutoff30) < 0 &&
                                    status == 'pending') {
                                  alerts.add({
                                    'level': 'warning',
                                    'title': 'Old pending transaction',
                                    'subtitle': '$txId | $service | $staff',
                                    'value': '${amount.toStringAsFixed(2)} USD',
                                    'time': _fmtTs(createdAt),
                                    'icon': Icons.history_toggle_off,
                                  });
                                }
                              }

                              final filtered = alerts.where((a) {
                                return _matchFilter((a['level'] ?? '').toString());
                              }).toList();

                              filtered.sort((a, b) {
                                int priority(String level) {
                                  if (level == 'critical') return 0;
                                  if (level == 'warning') return 1;
                                  return 2;
                                }
                                return priority((a['level'] ?? '').toString())
                                    .compareTo(priority((b['level'] ?? '').toString()));
                              });

                              final criticalCount =
                                  alerts.where((a) => a['level'] == 'critical').length;
                              final warningCount =
                                  alerts.where((a) => a['level'] == 'warning').length;
                              final infoCount =
                                  alerts.where((a) => a['level'] == 'info').length;

                              if (filtered.isEmpty) {
                                return ListView(
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _statBox('Critical', '$criticalCount', Colors.red),
                                        _statBox('Warning', '$warningCount', Colors.orange),
                                        _statBox('Info', '$infoCount', Colors.blue),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Card(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text('Pa gen alt pou filt sa a.'),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return ListView(
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      _statBox('Critical', '$criticalCount', Colors.red),
                                      _statBox('Warning', '$warningCount', Colors.orange),
                                      _statBox('Info', '$infoCount', Colors.blue),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  ...filtered.map((a) {
                                    final level = (a['level'] ?? '').toString();
                                    return Card(
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              _levelColor(level).withValues(alpha: 0.14),
                                          child: Icon(
                                            a['icon'] as IconData? ?? _levelIcon(level),
                                            color: _levelColor(level),
                                          ),
                                        ),
                                        title: Text(a['title'].toString()),
                                        subtitle: Text(
                                          '${a['subtitle']}\nTime: ${a['time']}',
                                        ),
                                        isThreeLine: true,
                                        trailing: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              a['value'].toString(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              level.toUpperCase(),
                                              style: TextStyle(
                                                color: _levelColor(level),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
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
      ),
    );
  }
}