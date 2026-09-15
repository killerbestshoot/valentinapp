import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Rapò antrepriz: volim, estati tranzaksyon yo, komisyon pa staff.
///
/// Tout chif yo kalkile sou TOUT antrepriz la sou serveur a — pa sou yon paj
/// 10 tranzaksyon, e pa melanje deviz ansanm.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  Future<(TransactionStats, List<CommissionSummary>)> _load() async {
    final results = await Future.wait([
      TransactionApi.instance.stats(),
      CommissionsApi.instance.summary(),
    ]);
    return (results[0] as TransactionStats, results[1] as List<CommissionSummary>);
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Rapò',
      children: [
        const DashboardHero(
          icon: Icons.bar_chart_outlined,
          title: 'Rapò',
          subtitle: 'Volim, estati ak komisyon antrepriz la.',
        ),
        const SizedBox(height: 18),
        AsyncView<(TransactionStats, List<CommissionSummary>)>(
          load: _load,
          builder: (context, data, _) {
            final (stats, commissions) = data;
            final deliveryRate =
                stats.total == 0 ? 0 : (stats.delivered / stats.total * 100).round();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DashboardPanel(
                  child: Column(
                    children: [
                      _Metric(label: 'Tranzaksyon', value: '${stats.total}'),
                      _Metric(label: 'Livre', value: '${stats.delivered} ($deliveryRate%)'),
                      _Metric(label: 'An atant', value: '${stats.pending}'),
                      _Metric(label: 'Echwe / anile', value: '${stats.failed}'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Volim pa deviz'),
                DashboardPanel(
                  child: stats.volumes.isEmpty
                      ? const Text('Pa gen volim ankò.',
                          style: TextStyle(color: DashboardColors.muted))
                      : Column(
                          children: stats.volumes.entries
                              .map((e) => _Metric(
                                    label: e.key,
                                    value: e.value.toStringAsFixed(2),
                                  ))
                              .toList(),
                        ),
                ),
                const SizedBox(height: 18),
                const _SectionTitle('Komisyon pa staff'),
                DashboardPanel(
                  child: commissions.isEmpty
                      ? const Text('Pa gen komisyon ankò.',
                          style: TextStyle(color: DashboardColors.muted))
                      : Column(
                          children: commissions
                              .map((c) => _Metric(
                                    label: '${c.staffName} (${c.count} tx)',
                                    value: '${c.agentTotal.toStringAsFixed(2)} ${c.currency}',
                                  ))
                              .toList(),
                        ),
                ),
              ],
            );
          },
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
        style: const TextStyle(fontWeight: FontWeight.w900, color: DashboardColors.ink, fontSize: 16),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: DashboardColors.muted)),
          ),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w900, color: DashboardColors.ink)),
        ],
      ),
    );
  }
}
