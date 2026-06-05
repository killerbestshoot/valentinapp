import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/pages/agent/agents_page.dart';
import 'package:mon_premye_app/pages/payout/payout_approval_page.dart';
import 'package:mon_premye_app/pages/settings/settings_page.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
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

  Widget _tile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadUserDoc(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final userData = userSnap.data ?? <String, dynamic>{};
        final enterpriseId = (userData['enterpriseId'] ?? '').toString();
        final enterpriseName =
            (userData['enterpriseName'] ?? 'VOUPVAPCASH').toString();
        final displayName =
            (userData['displayName'] ?? userData['fullName'] ?? 'Administrator')
                .toString();

        return Scaffold(
          appBar: AppBar(
            title: const Text('ADMIN DASHBOARD'),
            actions: [
              IconButton(
                tooltip: 'Logout',
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
          body: SafeArea(
            child: enterpriseId.isEmpty
                ? const Center(
                    child: Text('enterpriseId pa disponib sou users/{uid}.'),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('enterprises')
                              .doc(enterpriseId)
                              .snapshots(),
                          builder: (context, enterpriseSnap) {
                            final enterprise = enterpriseSnap.data?.data() ??
                                <String, dynamic>{};
                            final balance = _asDouble(
                              enterprise['balance'] ??
                                  enterprise['liveBalance'],
                            );
                            final currency =
                                (enterprise['currency'] ?? 'USD').toString();

                            return Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    const Icon(Icons.admin_panel_settings,
                                        size: 44),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'ADMIN ENTERPRISE OVERVIEW',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      enterpriseName,
                                      style: const TextStyle(fontSize: 20),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      displayName,
                                      style: const TextStyle(fontSize: 18),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Enterprise: $enterpriseId',
                                      style: const TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      '${balance.toStringAsFixed(2)} $currency',
                                      style: const TextStyle(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'QUICK ACTIONS',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.5,
                          children: [
                            _tile(
                              icon: Icons.groups,
                              label: 'Agents',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AgentsPage(),
                                  ),
                                );
                              },
                            ),
                            _tile(
                              icon: Icons.verified_user_outlined,
                              label: 'Payout Approval',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PayoutApprovalPage(),
                                  ),
                                );
                              },
                            ),
                            _tile(
                              icon: Icons.settings,
                              label: 'Settings',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsPage(),
                                  ),
                                );
                              },
                            ),
                            _tile(
                              icon: Icons.receipt_long,
                              label: 'Pending Requests',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'ACTIVE AGENTS',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .where('enterpriseId', isEqualTo: enterpriseId)
                              .where('role', whereIn: [
                            'agent',
                            'administrator'
                          ]).snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snap.hasError) {
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('Erreur: ${snap.error}'),
                                ),
                              );
                            }

                            final docs = snap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                      'Pa gen users aktif pou enterprise sa a.'),
                                ),
                              );
                            }

                            return Column(
                              children: docs.map((d) {
                                final m = d.data();
                                final name = (m['displayName'] ??
                                        m['fullName'] ??
                                        m['email'] ??
                                        d.id)
                                    .toString();
                                final role = (m['role'] ?? '').toString();
                                final email = (m['email'] ?? '').toString();

                                return Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(name),
                                    subtitle: Text('$role | $email'),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'PENDING PAYOUT REQUESTS',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('payout_requests')
                              .where('enterpriseId', isEqualTo: enterpriseId)
                              .where('status', isEqualTo: 'pending')
                              .snapshots(),
                          builder: (context, snap) {
                            if (snap.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }

                            if (snap.hasError) {
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('Erreur: ${snap.error}'),
                                ),
                              );
                            }

                            final docs = snap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('Pa gen payout request pending.'),
                                ),
                              );
                            }

                            return Column(
                              children: docs.map((d) {
                                final m = d.data();
                                final amount = _asDouble(m['amount']);
                                final currency =
                                    (m['currency'] ?? 'USD').toString();
                                final uid = (m['uid'] ?? '').toString();
                                final serviceName =
                                    (m['serviceName'] ?? '').toString();

                                return Card(
                                  child: ListTile(
                                    leading:
                                        const Icon(Icons.payments_outlined),
                                    title: Text(
                                      '${amount.toStringAsFixed(2)} $currency',
                                    ),
                                    subtitle: Text(
                                      'UID: $uid | Service: $serviceName',
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const PayoutApprovalPage(),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}
