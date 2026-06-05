import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/widgets/dashboard_ui.dart';

class WalletHistoryPage extends StatelessWidget {
  const WalletHistoryPage({super.key});

  static const String enterpriseId = 'ENT-001';

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _fmtTs(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Wallet History',
      children: [
        const DashboardHero(
          icon: Icons.history_outlined,
          title: 'Wallet history',
          subtitle: 'Track topups, transfers, and balance movement.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('wallet_history')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Erreur Firestore: ${snapshot.error}');
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return const Text('Pa gen history pou kounye a');
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final type = (data['type'] ?? '').toString();
                  final targetName = (data['targetName'] ?? '').toString();
                  final targetRole = (data['targetRole'] ?? '').toString();
                  final amount = _asDouble(data['amount']);
                  final before = _asDouble(data['balanceBefore']);
                  final after = _asDouble(data['balanceAfter']);
                  final requestedByName =
                      (data['requestedByName'] ?? '').toString();
                  final requestedByRole =
                      (data['requestedByRole'] ?? '').toString();
                  final date = _fmtTs(data['createdAt']);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: DashboardColors.soft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: DashboardColors.brand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$type - $targetName',
                                style: const TextStyle(
                                  color: DashboardColors.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$targetRole | Requested by $requestedByName ($requestedByRole)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: DashboardColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Before ${before.toStringAsFixed(2)} USD -> After ${after.toStringAsFixed(2)} USD | $date',
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
                          '${amount.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            color: DashboardColors.brand,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
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
