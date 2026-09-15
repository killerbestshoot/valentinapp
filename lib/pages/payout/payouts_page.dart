import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/payment_error_view.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Payout: yon staff mande pou yo peye l sòld li; yon admin apwouve.
///
/// Ranplase `payout_page`, `payout_approval_page` ak `withdraw_approval_page`
/// (twa ekran Firebase pou menm flux la).
///
/// Apwobasyon an voye lajan an VRE atravè Bazik. Erè Bazik yo (pwovizyon,
/// minimòm, nimewo) parèt ak `PaymentErrorView`.
class PayoutsPage extends StatefulWidget {
  const PayoutsPage({super.key});

  @override
  State<PayoutsPage> createState() => _PayoutsPageState();
}

class _PayoutsPageState extends State<PayoutsPage> {
  final _listKey = GlobalKey<AsyncViewState<List<PayoutRequest>>>();
  String? _busyId;
  PaymentException? _error;

  bool get _isManager {
    final role = AuthRepositoryProvider.instance.currentUser?.role;
    return role == AppRole.owner || role == AppRole.admin;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _request() async {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var network = 'moncash';

    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setDialogState) => AlertDialog(
              title: const Text('Mande yon payout'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'moncash', label: Text('MonCash')),
                        ButtonSegment(value: 'natcash', label: Text('NatCash')),
                      ],
                      selected: {network},
                      onSelectionChanged: (s) => setDialogState(() => network = s.first),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Montan'),
                      validator: (v) {
                        final n = double.tryParse((v ?? '').replaceAll(',', '.').trim());
                        return (n == null || n <= 0) ? 'Montan an pa valid.' : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Nimewo ou',
                        hintText: '+509 3712 3456',
                      ),
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                        final local = digits.startsWith('509') ? digits.substring(3) : digits;
                        return local.length != 8 ? 'Nimewo a dwe gen 8 chif.' : null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Anile'),
                ),
                FilledButton(
                  onPressed: () {
                    // Nou valide AVAN nou fèmen: si montan an pa bon, fòm nan
                    // pa pèdi (odit la te jwenn fòm ki te pèdi tout sa ki tape).
                    if (formKey.currentState!.validate()) {
                      Navigator.pop(dialogContext, true);
                    }
                  },
                  child: const Text('Voye demann lan'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.').trim());
    final phone = phoneCtrl.text.trim();
    amountCtrl.dispose();
    phoneCtrl.dispose();

    if (!ok || amount == null) return;

    try {
      await PayoutsApi.instance.request(amount: amount, phone: phone, network: network);
      _toast('Demann lan voye. Yon administratè ap apwouve l.');
      _listKey.currentState?.reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  Future<void> _approve(PayoutRequest payout) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Voye payout la?'),
            content: Text(
              'Nou pral voye ${payout.amount.toStringAsFixed(2)} ${payout.currency} '
              'bay ${payout.staffName} sou ${payout.network} (${payout.phone}), '
              'plis frè Bazik yo.\n\nLajan an pati TOUT SWIT.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anile'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Voye'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() {
      _busyId = payout.requestId;
      _error = null;
    });

    try {
      final result = await PayoutsApi.instance.approve(payout.requestId);
      _toast(result.status == 'approved' ? 'Payout la pati.' : 'Payout la echwe.');
    } on ApiException catch (err) {
      if (mounted) setState(() => _error = PaymentException(err.code, err.message));
    } finally {
      if (mounted) setState(() => _busyId = null);
      _listKey.currentState?.reload();
    }
  }

  Future<void> _reject(PayoutRequest payout) async {
    setState(() => _busyId = payout.requestId);
    try {
      await PayoutsApi.instance.reject(payout.requestId);
      _toast('Demann lan refize.');
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _busyId = null);
      _listKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Payout',
      children: [
        DashboardHero(
          icon: Icons.payments_outlined,
          title: 'Payout',
          subtitle: _isManager
              ? 'Apwouve demann payout staff yo.'
              : 'Mande pou yo peye sòld ou sou MonCash oswa NatCash.',
        ),
        const SizedBox(height: 18),
        if (!_isManager) ...[
          DashboardActionTile(
            icon: Icons.request_page_outlined,
            title: 'Mande yon payout',
            subtitle: 'Sòld ou pa debite anvan apwobasyon an',
            onTap: _request,
          ),
          const SizedBox(height: 18),
        ],
        if (_error != null) ...[
          PaymentErrorView(error: _error!),
          const SizedBox(height: 18),
        ],
        DashboardPanel(
          child: AsyncView<List<PayoutRequest>>(
            key: _listKey,
            load: () => PayoutsApi.instance.list(),
            isEmpty: (rows) => rows.isEmpty,
            emptyMessage: 'Pa gen demann payout.',
            builder: (context, rows, _) => Column(
              children: rows.map((payout) {
                final busy = _busyId == payout.requestId;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              payout.staffName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: DashboardColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${payout.amount.toStringAsFixed(2)} ${payout.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: DashboardColors.brand,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${payout.network} • ${payout.phone} • ${payout.status}',
                        style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
                      ),
                      if (payout.failureReason.isNotEmpty)
                        Text(
                          payout.failureReason,
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                        ),
                      if (_isManager && payout.isPending) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: busy ? null : () => _approve(payout),
                              icon: const Icon(Icons.send_outlined, size: 18),
                              label: const Text('Apwouve epi voye'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: busy ? null : () => _reject(payout),
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
