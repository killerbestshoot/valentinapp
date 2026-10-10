import 'package:flutter/material.dart';

import 'package:mon_premye_app/app/admin_shell.dart';
import 'package:mon_premye_app/pages/dashboard/owner_analytics_section.dart';
import 'package:mon_premye_app/core/config/app_environment.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/gateway_status_card.dart';
import 'package:mon_premye_app/features/wallet/presentation/widgets/exchange_rates_card.dart';
import 'package:mon_premye_app/pages/agent/agents_page.dart';
import 'package:mon_premye_app/pages/transactions/create_transaction_page.dart';
import 'package:mon_premye_app/pages/payout/payouts_page.dart';
import 'package:mon_premye_app/pages/commission/commissions_page.dart';
import 'package:mon_premye_app/pages/wallet/wallet_history_page.dart';
import 'package:mon_premye_app/pages/system/system_health_page.dart';
import 'package:mon_premye_app/pages/system/stuck_transfers_page.dart';
import 'package:mon_premye_app/pages/notifications/notifications_page.dart';
import 'package:mon_premye_app/pages/receipts/receipt_page.dart';
import 'package:mon_premye_app/pages/reports/reports_page.dart';
import 'package:mon_premye_app/pages/services/service_catalog_page.dart';
import 'package:mon_premye_app/pages/settings/settings_page.dart';
import 'package:mon_premye_app/pages/transactions/transaction_management_page.dart';
import 'package:mon_premye_app/pages/wallet/wallet_topup_approval_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static const _ink = Color(0xFF172116);
  static const _muted = Color(0xFF667365);
  static const _surface = Color(0xFFF4F8F1);
  static const _brand = Color(0xFF123D2B);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _analyticsKey = GlobalKey<OwnerAnalyticsSectionState>();

  void _refresh() {
    _analyticsKey.currentState?.reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tablo a rechaje.'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppEnvironment.mockFirebase) {
      return _MockAdminDashboard(
        email: AuthRepositoryProvider.instance.currentUser?.email ?? '',
        onCreate: () => _openCreateTransaction(context),
        onLogout: () => AuthRepositoryProvider.instance.signOut(),
      );
    }

    return AdminShell(
      onCreateTransaction: () => _openCreateTransaction(context),
      onRefresh: (id) {
        if (id == 'dashboard') _refresh();
      },
      destinations: [
        ShellDestination(
          id: 'dashboard',
          label: 'Tablo',
          icon: Icons.space_dashboard_outlined,
          builder: (context) => _DashboardBody(
            analyticsKey: _analyticsKey,
            onOpenReceipt: (id) => _openReceipt(context, id),
          ),
        ),
        ShellDestination(
          id: 'transactions',
          label: 'Tranzaksyon',
          icon: Icons.receipt_long_outlined,
          section: 'Operasyon',
          builder: (_) => const TransactionManagementPage(),
        ),
        ShellDestination(
          id: 'payouts',
          label: 'Payout',
          icon: Icons.task_alt_outlined,
          section: 'Operasyon',
          builder: (_) => const PayoutsPage(),
        ),
        ShellDestination(
          id: 'topups',
          label: 'Rechaj wallet',
          icon: Icons.fact_check_outlined,
          section: 'Operasyon',
          builder: (_) => const WalletTopupApprovalPage(),
        ),
        ShellDestination(
          id: 'agents',
          label: 'Ajan',
          icon: Icons.groups_outlined,
          section: 'Operasyon',
          builder: (_) => const AgentsPage(),
        ),
        ShellDestination(
          id: 'commissions',
          label: 'Komisyon',
          icon: Icons.percent,
          section: 'Lajan',
          builder: (_) => const CommissionsPage(),
        ),
        ShellDestination(
          id: 'services',
          label: 'Sèvis ak frè',
          icon: Icons.tune_outlined,
          section: 'Lajan',
          builder: (_) => const ServiceCatalogPage(),
        ),
        ShellDestination(
          id: 'reports',
          label: 'Rapò',
          icon: Icons.bar_chart_outlined,
          section: 'Lajan',
          builder: (_) => const ReportsPage(),
        ),
        ShellDestination(
          id: 'wallet',
          label: 'Istorik wallet',
          icon: Icons.history,
          section: 'Lajan',
          builder: (_) => const WalletHistoryPage(),
        ),
        ShellDestination(
          id: 'notifications',
          label: 'Notifikasyon',
          icon: Icons.notifications_outlined,
          section: 'Sistèm',
          badge: true,
          builder: (_) => const NotificationsPage(),
        ),
        ShellDestination(
          id: 'review',
          label: 'Pou verifye',
          icon: Icons.rule_outlined,
          section: 'Sistèm',
          builder: (_) => const StuckTransfersPage(),
        ),
        ShellDestination(
          id: 'health',
          label: 'Sante sistèm',
          icon: Icons.monitor_heart_outlined,
          section: 'Sistèm',
          builder: (_) => const SystemHealthPage(),
        ),
        ShellDestination(
          id: 'settings',
          label: 'Paramèt',
          icon: Icons.settings_outlined,
          section: 'Sistèm',
          builder: (_) => const SettingsPage(),
        ),
      ],
    );
  }

  void _openCreateTransaction(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTransactionPage()),
    );
  }

  void _openReceipt(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptPage(transactionId: id)),
    );
  }
}

/// Paj "Tablo": float Bazik la ak to jounen an an tèt, epi analiz owner a.
class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.analyticsKey, required this.onOpenReceipt});

  final GlobalKey<OwnerAnalyticsSectionState> analyticsKey;
  final void Function(String id) onOpenReceipt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      return ListView(
        padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, 18, isWide ? 28 : 16, 32),
        children: [
          // An tèt: sa owner a gade anvan tout bagay — float Bazik la ak to jounen an.
          if (isWide)
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: GatewayStatusCard()),
                SizedBox(width: 16),
                Expanded(flex: 2, child: ExchangeRatesCard()),
              ],
            )
          else ...const [
            GatewayStatusCard(),
            SizedBox(height: 12),
            ExchangeRatesCard(),
          ],
          const SizedBox(height: 18),
          OwnerAnalyticsSection(key: analyticsKey, isWide: isWide, onOpenReceipt: onOpenReceipt),
        ],
      );
    });
  }
}

class _AdminCommandCenter extends StatelessWidget {
  const _AdminCommandCenter({
    required this.isWide,
    required this.onOpen,
  });

  final bool isWide;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context) {
    const actions = [
      _AdminAction(
        title: 'Create Tx',
        subtitle: 'Start a new transfer',
        icon: Icons.add_circle_outline,
        color: Color(0xFF1F7A3A),
        page: CreateTransactionPage(),
      ),
      _AdminAction(
        title: 'My Agents',
        subtitle: 'Create and manage agents',
        icon: Icons.groups_outlined,
        color: Color(0xFF2563EB),
        page: AgentsPage(),
      ),
      _AdminAction(
        title: 'Transactions',
        subtitle: 'Track admin activity',
        icon: Icons.receipt_long_outlined,
        color: Color(0xFF334155),
        page: TransactionManagementPage(),
      ),
      _AdminAction(
        title: 'Payout',
        subtitle: 'Apwouve epi voye payout yo',
        icon: Icons.task_alt_outlined,
        color: Color(0xFFB45309),
        page: PayoutsPage(),
      ),
      _AdminAction(
        title: 'Topup Approval',
        subtitle: 'Review wallet requests',
        icon: Icons.fact_check_outlined,
        color: Color(0xFF7C3AED),
        page: WalletTopupApprovalPage(),
      ),
      _AdminAction(
        title: 'Services',
        subtitle: 'Control available services',
        icon: Icons.tune_outlined,
        color: Color(0xFF0F766E),
        page: ServiceCatalogPage(),
      ),
      _AdminAction(
        title: 'Reports',
        subtitle: 'See admin reporting',
        icon: Icons.bar_chart_outlined,
        color: Color(0xFF047857),
        page: ReportsPage(),
      ),
      _AdminAction(
        title: 'Komisyon',
        subtitle: 'Istorik ak total pa staff',
        icon: Icons.percent,
        color: Color(0xFF9333EA),
        page: CommissionsPage(),
      ),
      _AdminAction(
        title: 'Istorik wallet',
        subtitle: 'Mouvman kòb ou',
        icon: Icons.history,
        color: Color(0xFF0369A1),
        page: WalletHistoryPage(),
      ),
      _AdminAction(
        title: 'Notifikasyon',
        subtitle: 'Sa ki bezwen atansyon',
        icon: Icons.notifications_outlined,
        color: Color(0xFFDC2626),
        page: NotificationsPage(),
      ),
      _AdminAction(
        title: 'Sante sistèm',
        subtitle: 'Baz done ak pasrèl',
        icon: Icons.monitor_heart_outlined,
        color: Color(0xFF15803D),
        page: SystemHealthPage(),
      ),
      _AdminAction(
        title: 'Settings',
        subtitle: 'Admin configuration',
        icon: Icons.settings_outlined,
        color: Color(0xFF525252),
        page: SettingsPage(),
      ),
    ];

    final columns = isWide ? 4 : 2;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: HomePage._brand),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Admin command center',
                  style: TextStyle(
                    color: HomePage._ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 92,
            ),
            itemBuilder: (context, index) {
              final action = actions[index];
              return _AdminActionCard(
                action: action,
                onTap: () => onOpen(action.page),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AdminAction {
  const _AdminAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.page,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget page;
}

class _AdminActionCard extends StatelessWidget {
  const _AdminActionCard({
    required this.action,
    required this.onTap,
  });

  final _AdminAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FBF6),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDDE8D8)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, color: action.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePage._ink,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: HomePage._muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockAdminDashboard extends StatelessWidget {
  const _MockAdminDashboard({
    required this.email,
    required this.onCreate,
    required this.onLogout,
  });

  final String email;
  final VoidCallback onCreate;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    const stats = _DashboardStats.empty;

    return Scaffold(
      backgroundColor: HomePage._surface,
      appBar: AppBar(
        backgroundColor: HomePage._surface,
        elevation: 0,
        foregroundColor: HomePage._ink,
        titleSpacing: 24,
        title: const Text(
          'VOUPVAPCASH',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          IconButton(
            tooltip: 'Dekonekte',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              isWide ? 32 : 16,
              12,
              isWide ? 32 : 16,
              32,
            ),
            children: [
              _Header(isWide: isWide, onCreate: onCreate),
              const SizedBox(height: 18),
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    'Email: $email',
                    style: const TextStyle(
                      color: HomePage._muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              _AdminCommandCenter(
                isWide: isWide,
                onOpen: (page) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => page),
                ),
              ),
              const SizedBox(height: 18),
              _StatsGrid(stats: stats, isWide: isWide),
              const SizedBox(height: 18),
              isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          flex: 7,
                          child: _MockTransactionsPanel(),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 3,
                          child: _OperationsPanel(
                            stats: stats,
                            onCreate: onCreate,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _OperationsPanel(stats: stats, onCreate: onCreate),
                        const SizedBox(height: 18),
                        const _MockTransactionsPanel(),
                      ],
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _MockTransactionsPanel extends StatelessWidget {
  const _MockTransactionsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.list_alt_outlined, color: HomePage._brand),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dènye transactions',
                    style: TextStyle(
                      color: HomePage._ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 18),
            Text(
              'Mock Firebase aktif. Pa gen transaction live pou kounye a.',
              textAlign: TextAlign.center,
              style: TextStyle(color: HomePage._muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isWide,
    required this.onCreate,
  });

  final bool isWide;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        color: HomePage._brand,
        borderRadius: BorderRadius.circular(8),
      ),
      child: isWide
          ? Row(
              children: [
                const Expanded(child: _HeaderCopy()),
                const SizedBox(width: 24),
                _CreateButton(onPressed: onCreate),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeaderCopy(),
                const SizedBox(height: 18),
                _CreateButton(onPressed: onCreate),
              ],
            ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Suivi transactions, statuts, ak operasyon rapid.',
          style: TextStyle(
            color: Color(0xFFDDE8D8),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: HomePage._brand,
        minimumSize: const Size(210, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.add_circle_outline),
      label: const Text(
        'Nouvo transaction',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.isWide});

  final _DashboardStats stats;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        icon: Icons.receipt_long_outlined,
        label: 'Transactions',
        value: '${stats.total}',
        accent: const Color(0xFF1565C0),
      ),
      _MetricCard(
        icon: Icons.schedule_outlined,
        label: 'Pending',
        value: '${stats.pending}',
        accent: const Color(0xFFF57F17),
      ),
      _MetricCard(
        icon: Icons.check_circle_outline,
        label: 'Delivered',
        value: '${stats.delivered}',
        accent: const Color(0xFF2E7D32),
      ),
      _MetricCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Volume',
        value: stats.primaryVolume,
        footnote: stats.secondaryVolume,
        accent: const Color(0xFF6A1B9A),
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isWide ? 2.4 : 1.7,
      children: cards,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    this.footnote = '',
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  /// Liy anba a: sèvi pou lòt deviz yo nan volim nan.
  final String footnote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomePage._muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomePage._ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                if (footnote.isNotEmpty)
                  Text(
                    footnote,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomePage._muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({
    required this.stats,
    required this.onCreate,
  });

  final _DashboardStats stats;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Operations',
            style: TextStyle(
              color: HomePage._ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          const _HealthRow(
            label: 'App',
            value: 'Connecte',
            icon: Icons.cloud_done_outlined,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(height: 10),
          _HealthRow(
            label: 'Queue pending',
            value: '${stats.pending}',
            icon: Icons.pending_actions_outlined,
            color: const Color(0xFFF57F17),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: HomePage._brand,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nouvo transaction'),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: HomePage._muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: HomePage._ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.total,
    required this.pending,
    required this.delivered,
    required this.volumes,
  });

  final int total;
  final int pending;
  final int delivered;

  /// Volim pa deviz. Nou PA adisyone deviz diferan ansanm: 100 USD + 100 HTG
  /// pa fè 200 nan anyen.
  final Map<String, double> volumes;

  static const empty = _DashboardStats(
    total: 0,
    pending: 0,
    delivered: 0,
    volumes: {},
  );

  static String _format(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  /// Egzanp: "22588 MXN" oswa "22588 MXN + 1450 USD".
  String get volumeLabel {
    if (volumes.isEmpty) return '0';

    final entries = volumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.map((e) => '${_format(e.value)} ${e.key}').join(' + ');
  }

  /// Pou UI a: lè gen plizyè deviz, nou montre premye a an gwo epi rès la anba.
  String get primaryVolume {
    if (volumes.isEmpty) return '0';

    final entries = volumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return '${_format(entries.first.value)} ${entries.first.key}';
  }

  String get secondaryVolume {
    if (volumes.length < 2) return '';

    final entries = volumes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.skip(1).map((e) => '${_format(e.value)} ${e.key}').join(' + ');
  }

}
