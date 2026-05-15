import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'pages/recent_transactions_page.dart';
import 'pages/payout_approval_page.dart';
import 'pages/settings_page.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0;
  }

  String _money(dynamic value) => _toDouble(value).toStringAsFixed(2);

  DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _date(dynamic value) {
    final d = _toDate(value);
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mi = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd $hh:$mi';
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF111827)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => page),
          );
        },
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF111827)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard')),
        body: const Center(
          child: Text('User pa konekte.'),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Dashboard')),
            body: Center(
              child: Text('Erreur user: ${userSnap.error}'),
            ),
          );
        }

        final userData = userSnap.data?.data() ?? <String, dynamic>{};
        final enterpriseId = (userData['enterpriseId'] ?? '').toString();
        final enterpriseName =
            (userData['enterpriseName'] ?? 'VOUPVAPCASH').toString();
        final adminName =
            (userData['displayName'] ?? userData['fullName'] ?? 'Administrator')
                .toString();

        if (enterpriseId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Dashboard')),
            body: const Center(
              child: Text('enterpriseId pa disponib sou admin la.'),
            ),
          );
        }

        final enterpriseDoc = FirebaseFirestore.instance
            .collection('enterprises')
            .doc(enterpriseId)
            .snapshots();

        final transactionsStream = FirebaseFirestore.instance
            .collection('transactions')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .limit(100)
            .snapshots();

        final payoutsStream = FirebaseFirestore.instance
            .collection('payout_requests')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .where('status', isEqualTo: 'pending')
            .snapshots();

        final usersStream = FirebaseFirestore.instance
            .collection('users')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .snapshots();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: enterpriseDoc,
          builder: (context, entSnap) {
            final enterpriseData =
                entSnap.data?.data() ?? <String, dynamic>{};
            final enterpriseBalance = _money(enterpriseData['balance']);

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: transactionsStream,
              builder: (context, txSnap) {
                final txDocs = [...(txSnap.data?.docs ?? [])];
                txDocs.sort((a, b) {
                  final da = _toDate(a.data()['createdAt']);
                  final db = _toDate(b.data()['createdAt']);
                  return db.compareTo(da);
                });

                double totalSales = 0;
                for (final d in txDocs) {
                  totalSales += _toDouble(d.data()['paymentAmount']);
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: payoutsStream,
                  builder: (context, payoutSnap) {
                    final pendingPayouts =
                        (payoutSnap.data?.docs.length ?? 0).toString();

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: usersStream,
                      builder: (context, usersSnap) {
                        int agentsCount = 0;
                        int activeUsersCount = 0;

                        for (final d in (usersSnap.data?.docs ?? [])) {
                          final data = d.data();
                          final role = (data['role'] ?? '').toString();
                          final isActive = data['isActive'] != false;

                          if (isActive) {
                            activeUsersCount++;
                          }
                          if (role == 'agent') {
                            agentsCount++;
                          }
                        }

                        return Scaffold(
                          backgroundColor: const Color(0xFFF7F8FC),
                          appBar: AppBar(
                            elevation: 0,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF111827),
                            title: const Text(
                              'Admin Dashboard',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            actions: [
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: () {
                                  (context as Element).markNeedsBuild();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout),
                                onPressed: () async {
                                  await FirebaseAuth.instance.signOut();
                                },
                              ),
                            ],
                          ),
                          body: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF111827),
                                      Color(0xFF1F2937),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: const Icon(
                                        Icons.admin_panel_settings_outlined,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            adminName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            enterpriseName,
                                            style: const TextStyle(
                                              color: Color(0xFFD1D5DB),
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _metricCard(
                                    title: 'Balans Enterprise',
                                    value: '$enterpriseBalance USD',
                                    icon: Icons.account_balance_wallet_outlined,
                                  ),
                                  const SizedBox(width: 10),
                                  _metricCard(
                                    title: 'Total Vant',
                                    value: '${_money(totalSales)} USD',
                                    icon: Icons.payments_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _metricCard(
                                    title: 'Payout Pending',
                                    value: pendingPayouts,
                                    icon: Icons.pending_actions_outlined,
                                  ),
                                  const SizedBox(width: 10),
                                  _metricCard(
                                    title: 'Agents',
                                    value: agentsCount.toString(),
                                    icon: Icons.groups_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _metricCard(
                                    title: 'Users Aktif',
                                    value: activeUsersCount.toString(),
                                    icon: Icons.verified_user_outlined,
                                  ),
                                  const SizedBox(width: 10),
                                  _metricCard(
                                    title: 'Total Tranzaksyon',
                                    value: txDocs.length.toString(),
                                    icon: Icons.receipt_long_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Aksyon Rapid',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _actionTile(
                                context: context,
                                icon: Icons.verified_user_outlined,
                                title: 'Payout Approval',
                                page: const PayoutApprovalPage(),
                              ),
                              _actionTile(
                                context: context,
                                icon: Icons.receipt_long_outlined,
                                title: 'Recent Transactions',
                                page: const RecentTransactionsPage(),
                              ),
                              _actionTile(
                                context: context,
                                icon: Icons.settings_outlined,
                                title: 'Paramt',
                                page: const SettingsPage(),
                              ),
                              const SizedBox(height: 22),
                              const Text(
                                'Dnye Tranzaksyon Yo',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (txDocs.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: const Text('Pa gen tranzaksyon ank.'),
                                )
                              else
                                ...txDocs.take(8).map((d) {
                                  final m = d.data();
                                  final serviceName =
                                      (m['serviceName'] ?? 'Service').toString();
                                  final customerPhone =
                                      (m['customerPhone'] ?? '').toString();
                                  final amount = _money(m['paymentAmount']);
                                  final status =
                                      (m['status'] ?? 'unknown').toString();
                                  final createdAt = _date(m['createdAt']);

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: const Color(0xFFE5E7EB),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const CircleAvatar(
                                              backgroundColor:
                                                  Color(0xFFF3F4F6),
                                              child: Icon(
                                                Icons.receipt_long_outlined,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                serviceName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$amount USD',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text('Tel: $customerPhone'),
                                        const SizedBox(height: 4),
                                        Text('Status: $status'),
                                        const SizedBox(height: 4),
                                        Text('Dat: $createdAt'),
                                      ],
                                    ),
                                  );
                                }),
                              const SizedBox(height: 24),
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
        );
      },
    );
  }
}