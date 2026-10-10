import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Komisyon: an dirèk pou owner a, istorik, total pa staff, epi aplikasyon an reta.
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
          subtitle: 'Yo soti nan frè chak tranzaksyon, aplike otomatikman lè l livre.',
        ),
        const SizedBox(height: 18),
        if (_isManager) ...[
          const _SectionTitle('An dirèk'),
          const LiveCommissionsPanel(),
          const SizedBox(height: 18),
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

/// Komisyon tout ajan yo, mete ajou chak [refreshEvery].
///
/// Owner a wè sa chak ajan touche (livre) ak sa ki an atant (transfè an
/// chemen), plis pati pa l apre frè pasrèl la.
class LiveCommissionsPanel extends StatefulWidget {
  const LiveCommissionsPanel({super.key, this.refreshEvery = const Duration(seconds: 10)});

  final Duration refreshEvery;

  @override
  State<LiveCommissionsPanel> createState() => _LiveCommissionsPanelState();
}

class _LiveCommissionsPanelState extends State<LiveCommissionsPanel> {
  static const _periods = {1: 'Jodi a', 7: '7 jou', 30: '30 jou'};
  static const _currencies = ['HTG', 'USD', 'MXN'];

  int _days = 1;
  String _currency = 'HTG';
  LiveCommissions? _data;
  String? _error;
  DateTime? _updatedAt;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refreshEvery, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await CommissionsApi.instance.live(days: _days, currency: _currency);
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _updatedAt = DateTime.now();
      });
    } on ApiException catch (err) {
      if (mounted) setState(() => _error = err.message);
    } catch (err) {
      if (mounted) setState(() => _error = '$err');
    } finally {
      _loading = false;
    }
  }

  void _select({int? days, String? currency}) {
    setState(() {
      _days = days ?? _days;
      _currency = currency ?? _currency;
      _data = null;
    });
    _load();
  }

  String _money(double v) => '${v.toStringAsFixed(2)} $_currency';

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<int>(
                segments: _periods.entries
                    .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                    .toList(),
                selected: {_days},
                showSelectedIcon: false,
                onSelectionChanged: (v) => _select(days: v.first),
              ),
              SegmentedButton<String>(
                segments: _currencies.map((c) => ButtonSegment(value: c, label: Text(c))).toList(),
                selected: {_currency},
                showSelectedIcon: false,
                onSelectionChanged: (v) => _select(currency: v.first),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _error == null ? DashboardColors.brand : DashboardColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _error != null
                        ? 'Koneksyon an koupe'
                        : _updatedAt == null
                            ? 'N ap chaje...'
                            : 'An dirèk · ${_time(_updatedAt!)}',
                    style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: DashboardColors.danger, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          if (data == null)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Stat(label: 'Frè touche', value: _money(data.fee), hint: '${data.count} tranzaksyon livre'),
                _Stat(label: 'Komisyon ajan yo', value: _money(data.agentCommission)),
                _Stat(label: 'Frè pasrèl', value: _money(data.gatewayCost)),
                _Stat(
                  label: 'Pati ou (nèt)',
                  value: _money(data.ownerNet),
                  strong: true,
                  danger: data.ownerNet < 0,
                ),
                _Stat(
                  label: 'An atant',
                  value: _money(data.pendingAgent + data.pendingOwner),
                  hint: 'ajan ${_money(data.pendingAgent)}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (data.agents.isEmpty)
              const Text('Pa gen ajan ankò.', style: TextStyle(color: DashboardColors.muted))
            else
              ...data.agents.map(
                (a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: DashboardColors.soft,
                        child: Text(
                          a.staffName.isEmpty ? '?' : a.staffName.characters.first.toUpperCase(),
                          style: const TextStyle(
                              color: DashboardColors.brand, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.staffName.isEmpty ? '—' : a.staffName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, color: DashboardColors.ink),
                            ),
                            Text(
                              '${a.count} livre • frè ${_money(a.fee)}'
                              '${a.pendingCount > 0 ? ' • ${a.pendingCount} an atant (+${_money(a.pendingAgent)})' : ''}',
                              style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '+${_money(a.agentCommission)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, color: DashboardColors.brand),
                          ),
                          Text(
                            'ou: ${_money(a.ownerNet)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: a.ownerNet < 0 ? DashboardColors.danger : DashboardColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.hint,
    this.strong = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final String? hint;
  final bool strong;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = strong ? DashboardColors.surface : DashboardColors.ink;
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: strong ? (danger ? DashboardColors.danger : DashboardColors.brand) : DashboardColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: strong ? Colors.transparent : DashboardColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: strong ? fg.withValues(alpha: 0.8) : DashboardColors.muted)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: fg)),
          if (hint != null)
            Text(hint!,
                style: TextStyle(
                    fontSize: 11, color: strong ? fg.withValues(alpha: 0.8) : DashboardColors.muted)),
        ],
      ),
    );
  }
}
