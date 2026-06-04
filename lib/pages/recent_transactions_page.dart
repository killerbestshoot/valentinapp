import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../widgets/dashboard_ui.dart';

class RecentTransactionsPage extends StatelessWidget {
  const RecentTransactionsPage({super.key});

  String money(v) {
    final n = double.tryParse((v ?? 0).toString()) ?? 0;
    return NumberFormat('#,##0.00').format(n);
  }

  String date(v) {
    if (v is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm').format(v.toDate());
    }
    return '';
  }

  Widget _transactionCard(QueryDocumentSnapshot doc) {
    final tx = doc.data() as Map<String, dynamic>;
    final service = (tx['serviceName'] ?? 'Service').toString();
    final amount =
        '${money(tx['amount'] ?? tx['paymentAmount'])} ${tx['paymentCurrency'] ?? ''}';

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: DashboardColors.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: DashboardColors.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  service,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DashboardColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                amount,
                style: const TextStyle(
                  color: DashboardColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DashboardInfoRow(label: 'Status', value: '${tx['status'] ?? '-'}'),
          DashboardInfoRow(
              label: 'Client', value: '${tx['customerName'] ?? '-'}'),
          DashboardInfoRow(
              label: 'Phone', value: '${tx['customerPhone'] ?? '-'}'),
          DashboardInfoRow(label: 'Date', value: date(tx['createdAt'])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Recent transactions',
      children: [
        const DashboardHero(
          icon: Icons.history_outlined,
          title: 'Recent transactions',
          subtitle: 'Latest receipts and transaction activity.',
        ),
        const SizedBox(height: 18),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, s) {
            if (s.hasError) {
              return DashboardPanel(child: Text('ERROR: ${s.error}'));
            }

            if (s.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = s.data?.docs ?? [];

            if (docs.isEmpty) {
              return const DashboardPanel(child: Text('Pa gen tranzaksyon'));
            }

            return Column(
              children: [
                for (final doc in docs) ...[
                  _transactionCard(doc),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const RecentTransactionsPage();
  }
}
