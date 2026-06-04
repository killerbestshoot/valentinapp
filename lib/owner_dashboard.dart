import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'pages/agents_page.dart';
import 'pages/auth_debug_page.dart';
import 'pages/commission_history_page.dart';
import 'pages/new_transaction_page.dart';
import 'pages/owner_admin_wallet_dashboard_page.dart';
import 'pages/payout_page.dart';
import 'pages/receipt_page.dart';
import 'pages/reports_page.dart';
import 'pages/run_commission_page.dart';
import 'pages/send_page.dart';
import 'pages/settings_page.dart';
import 'pages/topup_page.dart';
import 'pages/transaction_management_page.dart';
import 'pages/user_role_manager_page.dart';
import 'pages/wallet_history_page.dart';
import 'pages/wallet_topup_approval_page.dart';
import 'widgets/logout_action.dart';

class _OwnerUi {
  static const ink = Color(0xFF172116);
  static const muted = Color(0xFF667365);
  static const surface = Color(0xFFF4F8F1);
  static const brand = Color(0xFF123D2B);
  static const border = Color(0xFFDDE8D8);
  static const soft = Color(0xFFF2F8EE);
}

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({
    super.key,
    this.enterpriseId = 'ENT-001',
    this.enterpriseName = 'VOUPVAPCASH',
    this.displayName = 'Owner',
    this.email = '',
    this.userId = '',
  });

  final String enterpriseId;
  final String enterpriseName;
  final String displayName;
  final String email;
  final String userId;

  String get _resolvedEnterpriseId {
    final value = enterpriseId.trim();
    return value.isEmpty ? 'ENT-001' : value;
  }

  String get _resolvedEnterpriseName {
    final value = enterpriseName.trim();
    return value.isEmpty ? 'VOUPVAPCASH' : value;
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  List<_DashboardAction> _actions(BuildContext context) {
    return [
      _DashboardAction(
        title: 'New Tx',
        subtitle: 'Create a transaction',
        icon: Icons.add_circle_outline,
        color: const Color(0xFF1F7A3A),
        onTap: () => _open(context, const NewTransactionPage()),
      ),
      _DashboardAction(
        title: 'Send',
        subtitle: 'Send money flow',
        icon: Icons.send_outlined,
        color: const Color(0xFF0B6E99),
        onTap: () => _open(context, const SendPage()),
      ),
      _DashboardAction(
        title: 'Payout',
        subtitle: 'Create payout request',
        icon: Icons.payments_outlined,
        color: const Color(0xFF8A5A12),
        onTap: () => _open(context, const PayoutPage()),
      ),
      _DashboardAction(
        title: 'Topup',
        subtitle: 'Recharge accounts',
        icon: Icons.phone_android_outlined,
        color: const Color(0xFF6F4BC1),
        onTap: () => _open(context, const TopupPage()),
      ),
      _DashboardAction(
        title: 'Wallets',
        subtitle: 'Live balances',
        icon: Icons.account_balance_wallet_outlined,
        color: const Color(0xFF0F766E),
        onTap: () => _open(context, const OwnerAdminWalletDashboardPage()),
      ),
      _DashboardAction(
        title: 'Topup Approval',
        subtitle: 'Review requests',
        icon: Icons.fact_check_outlined,
        color: const Color(0xFFB45309),
        onTap: () => _open(context, const WalletTopupApprovalPage()),
      ),
      _DashboardAction(
        title: 'Agents',
        subtitle: 'Manage field staff',
        icon: Icons.groups_outlined,
        color: const Color(0xFF2563EB),
        onTap: () => _open(context, const AgentsPage()),
      ),
      _DashboardAction(
        title: 'Users',
        subtitle: 'Roles and access',
        icon: Icons.manage_accounts_outlined,
        color: const Color(0xFF7C3AED),
        onTap: () => _open(context, const UserRoleManagerPage()),
      ),
      _DashboardAction(
        title: 'Transactions',
        subtitle: 'Audit operations',
        icon: Icons.receipt_long_outlined,
        color: const Color(0xFF334155),
        onTap: () => _open(context, const TransactionManagementPage()),
      ),
      _DashboardAction(
        title: 'Wallet History',
        subtitle: 'Ledger activity',
        icon: Icons.history_outlined,
        color: const Color(0xFF475569),
        onTap: () => _open(context, const WalletHistoryPage()),
      ),
      _DashboardAction(
        title: 'Commission',
        subtitle: 'Run automation',
        icon: Icons.percent_outlined,
        color: const Color(0xFFBE123C),
        onTap: () => _open(context, const RunCommissionPage()),
      ),
      _DashboardAction(
        title: 'Reports',
        subtitle: 'Owner reporting',
        icon: Icons.bar_chart_outlined,
        color: const Color(0xFF047857),
        onTap: () => _open(context, const ReportsPage()),
      ),
      _DashboardAction(
        title: 'Commission Logs',
        subtitle: 'Review payouts',
        icon: Icons.assignment_outlined,
        color: const Color(0xFF9333EA),
        onTap: () => _open(context, const CommissionHistoryPage()),
      ),
      _DashboardAction(
        title: 'Settings',
        subtitle: 'Enterprise setup',
        icon: Icons.settings_outlined,
        color: const Color(0xFF525252),
        onTap: () => _open(context, const SettingsPage()),
      ),
      _DashboardAction(
        title: 'Auth Debug',
        subtitle: 'Session diagnostics',
        icon: Icons.verified_user_outlined,
        color: const Color(0xFF0F172A),
        onTap: () => _open(context, const AuthDebugPage()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final resolvedEnterpriseId = _resolvedEnterpriseId;
    final resolvedEnterpriseName = _resolvedEnterpriseName;

    return Scaffold(
      backgroundColor: _OwnerUi.surface,
      appBar: AppBar(
        backgroundColor: _OwnerUi.surface,
        elevation: 0,
        foregroundColor: _OwnerUi.ink,
        titleSpacing: 24,
        title: const Text(
          'VOUPVAPCASH Owner',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: const [LogoutAction()],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                _OwnerHeader(
                  enterpriseId: resolvedEnterpriseId,
                  enterpriseName: resolvedEnterpriseName,
                  displayName: displayName,
                  email: email,
                  userId: userId,
                ),
                const SizedBox(height: 18),
                _MetricGrid(enterpriseId: resolvedEnterpriseId),
                const SizedBox(height: 18),
                _SectionHeader(
                  title: 'Owner command center',
                  action: IconButton(
                    tooltip: 'Open transactions',
                    onPressed: () => _open(
                      context,
                      const TransactionManagementPage(),
                    ),
                    icon: const Icon(Icons.open_in_new),
                  ),
                ),
                _ActionGrid(actions: _actions(context)),
                const SizedBox(height: 18),
                _RecentTransactionsPanel(
                  enterpriseId: resolvedEnterpriseId,
                  onOpenReceipt: (transactionId) {
                    _open(
                      context,
                      ReceiptPage(transactionId: transactionId),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnerHeader extends StatelessWidget {
  const _OwnerHeader({
    required this.enterpriseId,
    required this.enterpriseName,
    required this.displayName,
    required this.email,
    required this.userId,
  });

  final String enterpriseId;
  final String enterpriseName;
  final String displayName;
  final String email;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 820;

        return Container(
          padding: EdgeInsets.all(wide ? 28 : 20),
          decoration: BoxDecoration(
            color: _OwnerUi.brand,
            borderRadius: BorderRadius.circular(8),
          ),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 6,
                      child: _OwnerHeroCopy(
                        enterpriseId: enterpriseId,
                        enterpriseName: enterpriseName,
                        displayName: displayName,
                        email: email,
                        userId: userId,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 4,
                      child: _OwnerBalanceSummary(
                        enterpriseId: enterpriseId,
                        enterpriseName: enterpriseName,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OwnerHeroCopy(
                      enterpriseId: enterpriseId,
                      enterpriseName: enterpriseName,
                      displayName: displayName,
                      email: email,
                      userId: userId,
                    ),
                    const SizedBox(height: 18),
                    _OwnerBalanceSummary(
                      enterpriseId: enterpriseId,
                      enterpriseName: enterpriseName,
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _OwnerHeroCopy extends StatelessWidget {
  const _OwnerHeroCopy({
    required this.enterpriseId,
    required this.enterpriseName,
    required this.displayName,
    required this.email,
    required this.userId,
  });

  final String enterpriseId;
  final String enterpriseName;
  final String displayName;
  final String email;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.admin_panel_settings_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          enterpriseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Owner control center for wallets, people, payouts, and operations.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _HeroChip(
              icon: Icons.person_outline,
              text: displayName.trim().isEmpty ? 'Owner' : displayName,
            ),
            _HeroChip(
              icon: Icons.mail_outline,
              text: email.trim().isEmpty ? 'owner session' : email,
            ),
            _HeroChip(icon: Icons.business_outlined, text: enterpriseId),
            _HeroChip(
              icon: Icons.badge_outlined,
              text: userId.trim().isEmpty ? 'UUID pending' : userId,
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerBalanceSummary extends StatelessWidget {
  const _OwnerBalanceSummary({
    required this.enterpriseId,
    required this.enterpriseName,
  });

  final String enterpriseId;
  final String enterpriseName;

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final docId = '${enterpriseId}_OWNER';

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('balances')
          .doc(docId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final balance = _num(data['balance']);
        final reserved = _num(data['reserved']);
        final currency = (data['currency'] ?? 'USD').toString();

        return _InfoPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: _OwnerUi.brand,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Owner Live Balance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _OwnerUi.ink,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '${balance.toStringAsFixed(2)} $currency',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: _OwnerUi.ink,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                enterpriseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _OwnerUi.muted),
              ),
              const SizedBox(height: 14),
              _InfoLine(label: 'Reserved', value: reserved.toStringAsFixed(2)),
              _InfoLine(label: 'Balance Doc', value: docId),
              if (snapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Balance error: ${snapshot.error}',
                    style: const TextStyle(color: Color(0xFFB91C1C)),
                  ),
                )
              else if (!snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                )
              else if (!snapshot.data!.exists)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Balance doc poko kreye.'),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.enterpriseId});

  final String enterpriseId;

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 620
                ? 2
                : 1;

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 118,
          ),
          children: [
            _CountMetricCard(
              title: 'Transactions',
              icon: Icons.receipt_long_outlined,
              color: const Color(0xFF1F7A3A),
              stream: db
                  .collection('transactions')
                  .where('enterpriseId', isEqualTo: enterpriseId)
                  .snapshots(),
            ),
            _CountMetricCard(
              title: 'Active Agents',
              icon: Icons.groups_outlined,
              color: const Color(0xFF2563EB),
              stream: db
                  .collection('enterprise_users')
                  .where('enterpriseId', isEqualTo: enterpriseId)
                  .where('role', isEqualTo: 'agent')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
            ),
            _CountMetricCard(
              title: 'Pending Payouts',
              icon: Icons.pending_actions_outlined,
              color: const Color(0xFFB45309),
              stream: db
                  .collection('payout_requests')
                  .where('enterpriseId', isEqualTo: enterpriseId)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
            ),
            _CountMetricCard(
              title: 'Topup Requests',
              icon: Icons.fact_check_outlined,
              color: const Color(0xFF7C3AED),
              stream: db
                  .collection('wallet_topup_requests')
                  .where('enterpriseId', isEqualTo: enterpriseId)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
            ),
          ],
        );
      },
    );
  }
}

class _CountMetricCard extends StatelessWidget {
  const _CountMetricCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
  });

  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot<Map<String, dynamic>>> stream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length;
        final value = snapshot.hasError ? '!' : (count?.toString() ?? '...');

        return _InfoPanel(
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _OwnerUi.muted,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: snapshot.hasError
                                    ? const Color(0xFFB91C1C)
                                    : _OwnerUi.ink,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_DashboardAction> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1020
            ? 5
            : constraints.maxWidth >= 760
                ? 4
                : constraints.maxWidth >= 520
                    ? 3
                    : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 142,
          ),
          itemBuilder: (context, index) {
            return _ActionCard(action: actions[index]);
          },
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final _DashboardAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _OwnerUi.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, color: action.color),
              ),
              const Spacer(),
              Text(
                action.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _OwnerUi.ink,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                action.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _OwnerUi.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionsPanel extends StatelessWidget {
  const _RecentTransactionsPanel({
    required this.enterpriseId,
    required this.onOpenReceipt,
  });

  final String enterpriseId;
  final ValueChanged<String> onOpenReceipt;

  String _text(dynamic value, [String fallback = '-']) {
    final result = (value ?? '').toString().trim();
    return result.isEmpty ? fallback : result;
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString()) ?? 0;
  }

  String _fmtDate(dynamic value) {
    DateTime? date;
    if (value is Timestamp) date = value.toDate();
    if (value is String) date = DateTime.tryParse(value);
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return _InfoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(title: 'Recent transactions'),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('transactions')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .orderBy('createdAt', descending: true)
                .limit(8)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Transactions error: ${snapshot.error}',
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Pa gen tranzaksyon pou enterprise sa a.'),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final service = _text(data['serviceName'], 'Transaction');
                  final status = _text(data['status']);
                  final customer =
                      _text(data['customerName'] ?? data['beneficiaryName']);
                  final amount = _num(
                    data['paymentAmount'] ?? data['transferAmount'],
                  );
                  final currency = _text(
                    data['paymentCurrency'] ?? data['transferCurrency'],
                    'USD',
                  );

                  return _OwnerTransactionRow(
                    service: service,
                    customer: customer,
                    status: status,
                    date: _fmtDate(data['createdAt']),
                    amount: '${amount.toStringAsFixed(2)} $currency',
                    onTap: () => onOpenReceipt(doc.id),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
  });

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: _OwnerUi.ink,
                ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _OwnerTransactionRow extends StatelessWidget {
  const _OwnerTransactionRow({
    required this.service,
    required this.customer,
    required this.status,
    required this.date,
    required this.amount,
    required this.onTap,
  });

  final String service;
  final String customer;
  final String status;
  final String date;
  final String amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final delivered = normalized == 'delivered' ||
        normalized == 'livre' ||
        normalized == 'livrée';
    final statusColor =
        delivered ? const Color(0xFF2E7D32) : const Color(0xFFF57F17);
    final statusFill =
        delivered ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _OwnerUi.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _OwnerUi.brand,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        service,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _OwnerUi.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusFill,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$customer | $date',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _OwnerUi.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              amount,
              style: const TextStyle(
                color: _OwnerUi.brand,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: _OwnerUi.muted),
          ],
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _OwnerUi.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: _OwnerUi.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardAction {
  const _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
