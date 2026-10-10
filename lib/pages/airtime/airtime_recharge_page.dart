import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/airtime/data/airtime_recharge_api.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Rechaj kont airtime ajan an.
///
/// Ajan: mande yon rechaj (montan chwazi, nòt opsyonèl).
/// Owner/Admin: wè tout demann yo ak apwouve / refize.
class AirtimeRechargePage extends StatefulWidget {
  const AirtimeRechargePage({super.key});

  @override
  State<AirtimeRechargePage> createState() => _AirtimeRechargePageState();
}

class _AirtimeRechargePageState extends State<AirtimeRechargePage> {
  final _listKey = GlobalKey<AsyncViewState<List<AirtimeRechargeRequest>>>();
  String? _busyId;

  bool get _isManager {
    final role = AuthRepositoryProvider.instance.currentUser?.role;
    return role == AppRole.owner || role == AppRole.admin;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _request() async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Mande yon rechaj airtime'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Administratè a ap kredite kont ou apre apwobasyon. '
                    'Kòb la sèvi pou voye minit Digicel ak Natcom.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF607064)),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Montan', border: OutlineInputBorder()),
                    validator: (v) {
                      final n = double.tryParse(
                          (v ?? '').replaceAll(',', '.').trim());
                      return (n == null || n <= 0)
                          ? 'Antre yon montan valid.'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nòt (opsyonèl)',
                        border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anile'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Voye demann lan'),
              ),
            ],
          ),
        ) ??
        false;

    final amount =
        double.tryParse(amountCtrl.text.replaceAll(',', '.').trim());
    final note = noteCtrl.text.trim();
    amountCtrl.dispose();
    noteCtrl.dispose();

    if (!ok || amount == null) return;

    try {
      await AirtimeRechargeApi.instance.request(amount: amount, note: note);
      _toast('Demann lan voye. Yon administratè ap apwouve l.');
      _listKey.currentState?.reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  Future<void> _approve(AirtimeRechargeRequest req) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Apwouve rechaj airtime?'),
            content: Text(
              'Kredite ${req.amount.toStringAsFixed(2)} ${req.currency} '
              'nan kont ${req.agentName} pou voye minit.\n\n'
              'Lajan an soti nan pwovizyon antrepriz la.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anile'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Apwouve'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() => _busyId = req.requestId);
    try {
      await AirtimeRechargeApi.instance.approve(req.requestId);
      _toast('Rechaj apwouve. Wallet ${req.agentName} kredite.');
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
      _listKey.currentState?.reload();
    }
  }

  Future<void> _reject(AirtimeRechargeRequest req) async {
    setState(() => _busyId = req.requestId);
    try {
      await AirtimeRechargeApi.instance.reject(req.requestId);
      _toast('Demann lan refize.');
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
      _listKey.currentState?.reload();
    }
  }

  Color _statusColor(String status) => switch (status) {
        'approved' => const Color(0xFF15803D),
        'rejected' => const Color(0xFFB91C1C),
        _ => const Color(0xFFB45309),
      };

  String _statusLabel(String status) => switch (status) {
        'approved' => 'Apwouve',
        'rejected' => 'Refize',
        _ => 'An atant',
      };

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Rechaj Airtime',
      children: [
        DashboardHero(
          icon: Icons.phone_android_outlined,
          title: 'Kont Airtime',
          subtitle: _isManager
              ? 'Apwouve demann rechaj airtime staff yo.'
              : 'Mande kòb pou voye minit Digicel ak Natcom.',
        ),
        const SizedBox(height: 18),
        if (!_isManager) ...[
          DashboardActionTile(
            icon: Icons.add_circle_outline,
            title: 'Mande yon rechaj',
            subtitle: 'Kont ou ap kredite apre apwobasyon',
            onTap: _request,
          ),
          const SizedBox(height: 18),
        ],
        DashboardPanel(
          child: AsyncView<List<AirtimeRechargeRequest>>(
            key: _listKey,
            load: () => AirtimeRechargeApi.instance.list(),
            isEmpty: (rows) => rows.isEmpty,
            emptyMessage: 'Pa gen demann rechaj airtime.',
            builder: (context, rows, _) => Column(
              children: rows.map((r) {
                final busy = _busyId == r.requestId;
                final statusColor = _statusColor(r.status);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.agentName.isNotEmpty ? r.agentName : 'Ajan',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: DashboardColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${r.amount.toStringAsFixed(2)} ${r.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: DashboardColors.brand,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _statusLabel(r.status),
                              style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (r.note.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                r.note,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: DashboardColors.muted,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_isManager && r.isPending) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: busy ? null : () => _approve(r),
                              icon: const Icon(Icons.check_outlined, size: 18),
                              label: const Text('Apwouve'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: busy ? null : () => _reject(r),
                              child: const Text('Refize'),
                            ),
                          ],
                        ),
                      ],
                      const Divider(height: 20),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
