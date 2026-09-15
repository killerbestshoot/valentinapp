import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Komisyon: istorik, total pa staff, epi aplikasyon an reta.
///
/// Ranplase `run_commission_page` ak `commission_history_page`, ki te chita
/// sou Firebase. Komisyon yo aplike otomatikman lè yon tranzaksyon livre;
/// bouton "Aplike" a se sèlman yon rattrapage.
class CommissionsPage extends StatefulWidget {
  const CommissionsPage({super.key});

  @override
  State<CommissionsPage> createState() => _CommissionsPageState();
}

class _CommissionsPageState extends State<CommissionsPage> {
  final _historyKey = GlobalKey<AsyncViewState<List<CommissionEntry>>>();
  final _summaryKey = GlobalKey<AsyncViewState<List<CommissionSummary>>>();
  bool _running = false;

  bool get _isManager {
    final role = AuthRepositoryProvider.instance.currentUser?.role;
    return role == AppRole.owner || role == AppRole.admin;
  }

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final result = await CommissionsApi.instance.run();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          '${result.applied} komisyon aplike'
          '${result.errors > 0 ? ', ${result.errors} erè' : ''}.',
        ),
      ));
      _historyKey.currentState?.reload();
      _summaryKey.currentState?.reload();
    } on ApiException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Komisyon',
      children: [
        const DashboardHero(
          icon: Icons.percent,
          title: 'Komisyon',
          subtitle: 'Aplike otomatikman lè yon tranzaksyon livre.',
        ),
        const SizedBox(height: 18),
        if (_isManager) ...[
          DashboardActionTile(
            icon: Icons.play_circle_outline,
            title: _running ? 'N ap aplike...' : 'Aplike komisyon an reta yo',
            subtitle: 'Rattrapage san danje: yon komisyon pa janm aplike de fwa',
            onTap: _running ? null : _run,
          ),
          const SizedBox(height: 18),
          const _SectionTitle('Total pa staff'),
          DashboardPanel(
            child: AsyncView<List<CommissionSummary>>(
              key: _summaryKey,
              load: CommissionsApi.instance.summary,
              isEmpty: (rows) => rows.isEmpty,
              emptyMessage: 'Pa gen komisyon ankò.',
              builder: (context, rows, _) => Column(
                children: rows
                    .map((row) => _Row(
                          title: row.staffName.isEmpty ? '—' : row.staffName,
                          subtitle: '${row.count} tranzaksyon',
                          trailing:
                              '${row.agentTotal.toStringAsFixed(2)} ${row.currency}',
                        ))
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],
        const _SectionTitle('Istorik'),
        DashboardPanel(
          child: AsyncView<List<CommissionEntry>>(
            key: _historyKey,
            load: CommissionsApi.instance.history,
            isEmpty: (rows) => rows.isEmpty,
            emptyMessage: 'Pa gen komisyon ankò.',
            builder: (context, rows, _) => Column(
              children: rows
                  .map((row) => _Row(
                        title: '${row.service} — ${row.staffName}',
                        subtitle:
                            '${row.txAmount.toStringAsFixed(2)} ${row.txCurrency} • '
                            'ajan ${row.agentPct.toStringAsFixed(0)}% • '
                            'owner ${row.ownerPct.toStringAsFixed(0)}%',
                        trailing:
                            '+${row.agentCommission.toStringAsFixed(2)} ${row.txCurrency}',
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: DashboardColors.ink,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, required this.trailing});

  final String title;
  final String subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: DashboardColors.ink)),
                Text(subtitle,
                    style: const TextStyle(color: DashboardColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Text(trailing,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, color: DashboardColors.brand)),
        ],
      ),
    );
  }
}
