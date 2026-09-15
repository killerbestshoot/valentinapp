import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/config/app_environment.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';
import 'package:mon_premye_app/pages/transactions/create_transaction_page.dart';
import 'package:mon_premye_app/features/payments/presentation/pages/send_money_page.dart';
import 'package:mon_premye_app/pages/payout/payouts_page.dart';
import 'package:mon_premye_app/pages/settings/settings_page.dart';
import 'package:mon_premye_app/pages/transactions/transaction_management_page.dart';
import 'package:mon_premye_app/pages/wallet/wallet_history_page.dart';

class AgentDashboard extends StatelessWidget {
  const AgentDashboard({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    if (AppEnvironment.mockFirebase) {
      final user = AuthRepositoryProvider.instance.currentUser;
      return _AgentDashboardContent(
        name: user?.email ?? 'Agent',
        enterprise: 'VOUPVAPCASH',
        balance: 0,
        onOpen: (page) => _open(context, page),
        onLogout: () => AuthRepositoryProvider.instance.signOut(),
      );
    }

    // Non, antrepriz ak sòld vini nan yon sèl rekèt sou serveur a.
    return FutureBuilder<WalletSummary>(
      future: WalletApi.instance.mine(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: DashboardColors.surface,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final profile = AuthRepositoryProvider.instance.currentUser;
        final wallet = snap.data;

        if (snap.hasError) {
          final error = snap.error;
          return Scaffold(
            backgroundColor: DashboardColors.surface,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error is ApiException ? error.message : '$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            ),
          );
        }

        return _AgentDashboardContent(
          name: profile?.displayName.isNotEmpty == true
              ? profile!.displayName
              : (profile?.email ?? 'Agent'),
          enterprise: profile?.enterpriseName.isNotEmpty == true
              ? profile!.enterpriseName
              : 'VOUPVAPCASH',
          balance: wallet?.balance ?? 0,
          currency: wallet?.currency ?? 'USD',
          onOpen: (page) => _open(context, page),
          onLogout: () => AuthRepositoryProvider.instance.signOut(),
        );
      },
    );
  }
}

class _AgentDashboardContent extends StatelessWidget {
  const _AgentDashboardContent({
    required this.name,
    required this.enterprise,
    required this.balance,
    this.currency = 'USD',
    required this.onOpen,
    required this.onLogout,
  });

  final String name;
  final String enterprise;
  final double balance;

  /// Deviz wallet la — pa toujou USD.
  final String currency;
  final ValueChanged<Widget> onOpen;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Agent workspace',
      actions: [
        IconButton(
          tooltip: 'Dekonekte',
          icon: const Icon(Icons.logout),
          onPressed: onLogout,
        ),
        const SizedBox(width: 8),
      ],
      children: [
        DashboardHero(
          icon: Icons.person_pin_circle_outlined,
          title: name,
          subtitle: '$enterprise | Agent operations',
          trailing: _AgentBalanceCard(balance: balance, currency: currency),
        ),
        const SizedBox(height: 18),
        _AgentMetrics(balance: balance, currency: currency),
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
        _AgentActions(onOpen: onOpen),
      ],
    );
  }
}

class _AgentBalanceCard extends StatelessWidget {
  const _AgentBalanceCard({required this.balance, required this.currency});

  final double balance;
  final String currency;

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
            '${balance.toStringAsFixed(2)} $currency',
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

/// Metrik ajan an: TOUT soti nan rejis la, nan deviz wallet la.
///
/// Anvan, "Topup 2000 USD" ak "COM 450 USD" te konstant ki ekri an di,
/// afiche bò kote vrè sòld la. Ajan an t ap li twa chif, de ladan yo te envante.
/// Epi sòld la te toujou make "USD", menm pou yon wallet HTG oswa MXN.
class _AgentMetrics extends StatefulWidget {
  const _AgentMetrics({required this.balance, required this.currency});

  final double balance;
  final String currency;

  @override
  State<_AgentMetrics> createState() => _AgentMetricsState();
}

class _AgentMetricsState extends State<_AgentMetrics> {
  double _commissions = 0;
  double _topups = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = AuthRepositoryProvider.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    try {
      final entries = await WalletApi.instance.ledger(uid, limit: 200);
      if (!mounted) return;

      double sum(bool Function(LedgerEntry e) test) =>
          entries.where(test).fold(0, (total, e) => total + e.amount);

      setState(() {
        _commissions = sum((e) => e.isCredit && e.type == 'commission_agent');
        _topups = sum((e) => e.isCredit && e.type.startsWith('wallet_topup'));
      });
    } on ApiException {
      // Metrik segondè: si yo pa chaje, sòld la (ki pi enpòtan) rete vizib.
    }
  }

  @override
  Widget build(BuildContext context) {
    String fmt(double value) => '${value.toStringAsFixed(2)} ${widget.currency}';

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
            _Metric(label: 'Sòld', value: fmt(widget.balance)),
            _Metric(label: 'Rechaj resevwa', value: fmt(_topups)),
            _Metric(label: 'Komisyon', value: fmt(_commissions)),
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
    // `Chip` e pa `ActionChip`: se yon etikèt enfòmatif. Anvan, `onPressed: () {}`
    // te fè l anime lè ou tape l, san li pa fè anyen.
    return Chip(
      avatar: const Icon(Icons.check_circle_outline, size: 18),
      label: Text(label),
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
            title: 'Istorik wallet',
            subtitle: 'Rechaj, komisyon ak transfè',
            onTap: () => onOpen(const WalletHistoryPage()),
            color: const Color(0xFF6A1B9A),
          ),
          DashboardActionTile(
            icon: Icons.send_outlined,
            title: 'Send',
            subtitle: 'Voye lajan pou kliyan',
            onTap: () => onOpen(const SendMoneyPage()),
            color: const Color(0xFF1565C0),
          ),
          DashboardActionTile(
            icon: Icons.payments_outlined,
            title: 'Payout',
            subtitle: 'Mande pou yo peye sòld ou',
            onTap: () => onOpen(const PayoutsPage()),
            color: const Color(0xFFF57F17),
          ),
          DashboardActionTile(
            icon: Icons.receipt_long_outlined,
            title: 'Fich transactions',
            subtitle: 'Retrouve tout fich yo',
            onTap: () => onOpen(const TransactionManagementPage()),
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
