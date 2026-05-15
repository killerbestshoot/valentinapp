import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SystemHealthPage extends StatelessWidget {
  const SystemHealthPage({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'CRITICAL':
        return Colors.red;
      case 'WARNING':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'CRITICAL':
        return Icons.error;
      case 'WARNING':
        return Icons.warning_amber;
      default:
        return Icons.check_circle;
    }
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String status,
    required String detail,
  }) {
    final color = _statusColor(status);

    return Container(
      width: 260,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon(status), color: color, size: 28),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$status | $detail',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _countRisk(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String risk,
  ) {
    int total = 0;
    for (final d in docs) {
      final m = d.data();
      final customer = (m['customerRiskStatus'] ?? '').toString().toLowerCase();
      final beneficiary = (m['beneficiaryRiskStatus'] ?? '').toString().toLowerCase();
      if (customer == risk || beneficiary == risk) {
        total++;
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System Health'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userDocs = userSnap.data!.docs;
          final totalUsers = userDocs.length;
          final totalAgents = userDocs.where((d) {
            final role = (d.data()['role'] ?? '').toString().toLowerCase();
            return role == 'agent';
          }).length;

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .orderBy('createdAt', descending: true)
                .limit(500)
                .snapshots(),
            builder: (context, txSnap) {
              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final txDocs = txSnap.data!.docs;
              final totalTransactions = txDocs.length;

              final txWithoutCommission = txDocs.where((d) {
                final m = d.data();
                final staffRole = (m['staffRole'] ?? '').toString().toLowerCase();
                final status = (m['status'] ?? '').toString().toLowerCase();
                final paymentStatus = (m['paymentStatus'] ?? '').toString().toLowerCase();
                final applied = m['commissionApplied'] == true;

                return staffRole == 'agent' &&
                    status == 'delivered' &&
                    paymentStatus == 'paid' &&
                    !applied;
              }).length;

              final blacklistAlerts = _countRisk(txDocs, 'blacklist');
              final watchlistAlerts = _countRisk(txDocs, 'watchlist');

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('payout_requests')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (context, payoutSnap) {
                  if (!payoutSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final pendingPayouts = payoutSnap.data!.docs.length;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('client_flags')
                        .snapshots(),
                    builder: (context, flagSnap) {
                      if (!flagSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final flagDocs = flagSnap.data!.docs;
                      final blacklistClients = flagDocs.where((d) {
                        final s = (d.data()['status'] ?? '').toString().toLowerCase();
                        return s == 'blacklist';
                      }).length;

                      final watchlistClients = flagDocs.where((d) {
                        final s = (d.data()['status'] ?? '').toString().toLowerCase();
                        return s == 'watchlist';
                      }).length;

                      String commissionStatus = 'OK';
                      if (txWithoutCommission > 20) {
                        commissionStatus = 'CRITICAL';
                      } else if (txWithoutCommission > 0) {
                        commissionStatus = 'WARNING';
                      }

                      String payoutStatus = 'OK';
                      if (pendingPayouts > 15) {
                        payoutStatus = 'CRITICAL';
                      } else if (pendingPayouts > 0) {
                        payoutStatus = 'WARNING';
                      }

                      String blacklistStatus = 'OK';
                      if (blacklistAlerts > 0) {
                        blacklistStatus = 'CRITICAL';
                      }

                      String watchlistStatus = 'OK';
                      if (watchlistAlerts > 10) {
                        watchlistStatus = 'CRITICAL';
                      } else if (watchlistAlerts > 0) {
                        watchlistStatus = 'WARNING';
                      }

                      String usersStatus = totalUsers == 0 ? 'WARNING' : 'OK';
                      String agentsStatus = totalAgents == 0 ? 'CRITICAL' : 'OK';
                      String txStatus = totalTransactions == 0 ? 'WARNING' : 'OK';

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'LIVE SYSTEM STATUS',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _metricCard(
                                  title: 'Total Users',
                                  value: '$totalUsers',
                                  status: usersStatus,
                                  detail: 'registered accounts',
                                ),
                                _metricCard(
                                  title: 'Total Agents',
                                  value: '$totalAgents',
                                  status: agentsStatus,
                                  detail: 'active workforce',
                                ),
                                _metricCard(
                                  title: 'Total Transactions',
                                  value: '$totalTransactions',
                                  status: txStatus,
                                  detail: 'recent tx volume',
                                ),
                                _metricCard(
                                  title: 'Pending Payouts',
                                  value: '$pendingPayouts',
                                  status: payoutStatus,
                                  detail: 'waiting approval',
                                ),
                                _metricCard(
                                  title: 'Tx Without Commission',
                                  value: '$txWithoutCommission',
                                  status: commissionStatus,
                                  detail: 'paid + delivered + not applied',
                                ),
                                _metricCard(
                                  title: 'Blacklist Alerts',
                                  value: '$blacklistAlerts',
                                  status: blacklistStatus,
                                  detail: 'critical risk activity',
                                ),
                                _metricCard(
                                  title: 'Watchlist Alerts',
                                  value: '$watchlistAlerts',
                                  status: watchlistStatus,
                                  detail: 'monitor closely',
                                ),
                                _metricCard(
                                  title: 'Blacklist Clients',
                                  value: '$blacklistClients',
                                  status: blacklistClients > 0 ? 'WARNING' : 'OK',
                                  detail: 'flagged clients',
                                ),
                                _metricCard(
                                  title: 'Watchlist Clients',
                                  value: '$watchlistClients',
                                  status: watchlistClients > 0 ? 'WARNING' : 'OK',
                                  detail: 'monitored clients',
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HEALTH RULES',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text('OK = sistm nan estab'),
                                    Text('WARNING = gen bagay pou swiv'),
                                    Text('CRITICAL = bezwen aksyon rapid'),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }
}