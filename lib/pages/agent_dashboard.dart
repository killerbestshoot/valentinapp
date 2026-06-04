import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/dashboard_ui.dart';
import 'create_transaction_page.dart';
import 'recent_transactions_page.dart';
import 'send_page.dart';
import 'settings_page.dart';
import 'topup_page.dart';

class AgentDashboard extends StatelessWidget {
  const AgentDashboard({super.key});

  double _d(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(
            backgroundColor: DashboardColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = userSnap.data?.data() ?? {};
        final enterpriseId = (user['enterpriseId'] ?? '').toString();
        final name =
            (user['displayName'] ?? user['fullName'] ?? 'Agent').toString();
        final enterprise = (user['enterpriseName'] ?? 'VOUPVAPCASH').toString();

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('balances')
              .doc('${enterpriseId}_$uid')
              .snapshots(),
          builder: (context, balSnap) {
            final balance = _d(balSnap.data?.data()?['balance']);

            return DashboardPage(
              title: 'Agent workspace',
              actions: [
                IconButton(
                  tooltip: 'Dekonekte',
                  icon: const Icon(Icons.logout),
                  onPressed: () => FirebaseAuth.instance.signOut(),
                ),
                const SizedBox(width: 8),
              ],
              children: [
                DashboardHero(
                  icon: Icons.person_pin_circle_outlined,
                  title: name,
                  subtitle: '$enterprise | Agent operations',
                  trailing: _AgentBalanceCard(balance: balance),
                ),
                const SizedBox(height: 18),
                _AgentMetrics(balance: balance),
                const SizedBox(height: 18),
                const DashboardPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DashboardSectionTitle(title: 'Services'),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _ServiceChip(label: 'MonCash'),
                          _ServiceChip(label: 'NatCash'),
                          _ServiceChip(label: 'Minit Haiti'),
                          _ServiceChip(label: 'Pappadap'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _AgentActions(onOpen: (page) => _open(context, page)),
              ],
            );
          },
        );
      },
    );
  }
}

class _AgentBalanceCard extends StatelessWidget {
  const _AgentBalanceCard({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Solde',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${balance.toStringAsFixed(2)} USD',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentMetrics extends StatelessWidget {
  const _AgentMetrics({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : 1;
        return GridView.count(
          crossAxisCount: columns,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: constraints.maxWidth >= 760 ? 2.8 : 4,
          children: [
            _Metric(label: 'Solde', value: '${balance.toStringAsFixed(2)} USD'),
            const _Metric(label: 'Topup', value: '2000 USD'),
            const _Metric(label: 'COM', value: '450 USD'),
          ],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DashboardPanel(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: DashboardColors.brand.withValues(alpha: 0.12),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: DashboardColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: DashboardColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.check_circle_outline, size: 18),
      label: Text(label),
      onPressed: () {},
      backgroundColor: DashboardColors.soft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _AgentActions extends StatelessWidget {
  const _AgentActions({required this.onOpen});

  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final actions = [
          DashboardActionTile(
            icon: Icons.add_circle_outline,
            title: 'Nouvo transaction',
            subtitle: 'Kreye yon nouvo operasyon',
            onTap: () => onOpen(const CreateTransactionPage()),
          ),
          DashboardActionTile(
            icon: Icons.phone_android_outlined,
            title: 'Topup',
            subtitle: 'Rechaje kont topup',
            onTap: () => onOpen(const TopupPage()),
            color: const Color(0xFF6A1B9A),
          ),
          DashboardActionTile(
            icon: Icons.send_outlined,
            title: 'Send',
            subtitle: 'Voye lajan pou kliyan',
            onTap: () => onOpen(const SendPage()),
            color: const Color(0xFF1565C0),
          ),
          DashboardActionTile(
            icon: Icons.credit_card,
            title: 'Card recharge',
            subtitle: 'Fonksyon ap vini',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Fonksyon kredi/debit card ap vini.')),
              );
            },
            color: const Color(0xFFF57F17),
          ),
          DashboardActionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Fich transactions',
            subtitle: 'Retrouve tout fich yo',
            onTap: () => onOpen(const RecentTransactionsPage()),
            color: const Color(0xFF334155),
          ),
          DashboardActionTile(
            icon: Icons.settings_outlined,
            title: 'Paramèt',
            subtitle: 'Preferans ak kont',
            onTap: () => onOpen(const SettingsPage()),
            color: const Color(0xFF525252),
          ),
        ];

        return GridView.count(
          crossAxisCount: wide ? 2 : 1,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: wide ? 4 : 4.2,
          children: actions,
        );
      },
    );
  }
}
