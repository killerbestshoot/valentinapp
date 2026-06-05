import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/widgets/dashboard_ui.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  double _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Agents',
      children: [
        const DashboardHero(
          icon: Icons.groups_outlined,
          title: 'Agents',
          subtitle: 'Manage field staff and live balances.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('role', isEqualTo: 'agent')
                .snapshots(),
            builder: (context, usersSnap) {
              if (usersSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (usersSnap.hasError) {
                return Text('Erreur users: ${usersSnap.error}');
              }

              final users = usersSnap.data?.docs ?? [];
              if (users.isEmpty) {
                return const Text('Pa gen agent jwenn.');
              }

              return Column(
                children: users.map((userDoc) {
                  final u = userDoc.data();
                  final uid = userDoc.id;
                  final name =
                      (u['displayName'] ?? u['fullName'] ?? 'Agent').toString();
                  final email = (u['email'] ?? '').toString();
                  final enterpriseId = (u['enterpriseId'] ?? '').toString();

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                    future: enterpriseId.isEmpty
                        ? Future.value(null)
                        : FirebaseFirestore.instance
                            .collection('balances')
                            .doc('${enterpriseId}_$uid')
                            .get(),
                    builder: (context, balSnap) {
                      final balance =
                          _asDouble(balSnap.data?.data()?['balance']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: DashboardColors.soft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person_outline,
                                color: DashboardColors.brand,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: DashboardColors.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '$email | UID: $uid',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: DashboardColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${balance.toStringAsFixed(2)} USD',
                              style: const TextStyle(
                                color: DashboardColors.brand,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}
