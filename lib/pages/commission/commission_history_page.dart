import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/widgets/dashboard_ui.dart';

class CommissionHistoryPage extends StatelessWidget {
  const CommissionHistoryPage({super.key});

  Future<Map<String, dynamic>> _loadSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Pa gen user konekte.');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists || userDoc.data() == null) {
      throw Exception('users/{uid} pa egziste pou session sa a.');
    }

    final data = userDoc.data()!;
    return {
      'uid': user.uid,
      'role': (data['role'] ?? '').toString(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
      'displayName': (data['displayName'] ?? data['fullName'] ?? '').toString(),
    };
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v.toString()) ?? 0;
  }

  String _fmtDate(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:'
          '${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  Widget _commissionCard(QueryDocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data();

    final txId = (m['txId'] ?? m['transactionId'] ?? d.id).toString();
    final staffName = (m['staffName'] ?? '').toString();
    final staffRole = (m['staffRole'] ?? '').toString();
    final serviceName = (m['serviceName'] ?? '').toString();

    final paymentAmount = _asDouble(m['paymentAmount']);
    final commissionAgent = _asDouble(m['commissionAgent']);
    final commissionOwner = _asDouble(m['commissionOwner']);
    final agentAfter = _asDouble(m['agentBalanceAfter']);
    final ownerAfter = _asDouble(m['ownerBalanceAfter']);

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            txId,
            style: const TextStyle(
              color: DashboardColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          DashboardInfoRow(label: 'Service', value: serviceName),
          DashboardInfoRow(label: 'Staff', value: staffName),
          DashboardInfoRow(label: 'Role', value: staffRole),
          DashboardInfoRow(
            label: 'Amount',
            value: paymentAmount.toStringAsFixed(2),
          ),
          DashboardInfoRow(
            label: 'Agent com.',
            value: commissionAgent.toStringAsFixed(2),
          ),
          DashboardInfoRow(
            label: 'Owner com.',
            value: commissionOwner.toStringAsFixed(2),
          ),
          DashboardInfoRow(
            label: 'Agent after',
            value: agentAfter.toStringAsFixed(2),
          ),
          DashboardInfoRow(
            label: 'Owner after',
            value: ownerAfter.toStringAsFixed(2),
          ),
          DashboardInfoRow(
            label: 'Applied at',
            value: _fmtDate(m['commissionAppliedAt'] ?? m['createdAt']),
          ),
          const SizedBox(height: 6),
          SelectableText(
            'Doc ID: ${d.id}',
            style: const TextStyle(color: DashboardColors.muted),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Commission history',
      children: [
        const DashboardHero(
          icon: Icons.payments_outlined,
          title: 'Commission history',
          subtitle: 'Audit commission applied to enterprise transactions.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<Map<String, dynamic>>(
          future: _loadSession(),
          builder: (context, sessionSnap) {
            if (sessionSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (sessionSnap.hasError) {
              return DashboardPanel(
                child: Text('Er session: ${sessionSnap.error}'),
              );
            }

            final session = sessionSnap.data!;
            final role = (session['role'] ?? '').toString().toLowerCase();
            final enterpriseId = (session['enterpriseId'] ?? '').toString();

            if (enterpriseId.isEmpty) {
              return const DashboardPanel(
                child: Text('enterpriseId manke sou users/{uid}.'),
              );
            }

            if (role != 'owner' && role != 'administrator') {
              return const DashboardPanel(
                child: Text(
                  'Se owner oswa administrator slman ki ka w Commission History.',
                ),
              );
            }

            final stream = FirebaseFirestore.instance
                .collection('transactions')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .where('commissionApplied', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(100)
                .snapshots();

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return DashboardPanel(
                    child: Text(
                      'Er Firestore: ${snap.error}\n\n'
                      'Si li mande index, deploy firestore.indexes.json lan epi tann index la fin build.',
                    ),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const DashboardPanel(
                    child: Text(
                      'Pa gen commission ki deja aplike pou enterprise sa a.',
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final d in docs) ...[
                      _commissionCard(d),
                      const SizedBox(height: 12),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}
