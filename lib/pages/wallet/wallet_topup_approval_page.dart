import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/users/data/users_api.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Demann rechaj wallet: kreye, apwouve, refize.
///
/// Apwobasyon an pase pa `settleTopup` sou serveur a, ki kredite sòld la ak
/// ekri liy rejis la nan MENM tranzaksyon — epi ki refize yon dezyèm
/// apwobasyon sou menm demann lan.
class WalletTopupApprovalPage extends StatefulWidget {
  const WalletTopupApprovalPage({super.key});

  @override
  State<WalletTopupApprovalPage> createState() =>
      _WalletTopupApprovalPageState();
}

class _WalletTopupApprovalPageState extends State<WalletTopupApprovalPage> {
  late Future<List<TopupRequest>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = WalletApi.instance.topups();
  }

  void _reload() {
    // Apre yon `await`, ekran an ka deja fèmen.
    if (!mounted) return;
    setState(() {
      _future = WalletApi.instance.topups();
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _approve(TopupRequest request) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Apwouve rechaj la?'),
            content: Text(
              'Wallet ${request.targetName} ap kredite ak '
              '${request.amount.toStringAsFixed(2)} ${request.currency}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anile'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Apwouve'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() => _busy = true);
    try {
      await WalletApi.instance.approveTopup(request.requestId);
      _toast('Wallet la kredite.');
      _reload();
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(TopupRequest request) async {
    setState(() => _busy = true);
    try {
      await WalletApi.instance.rejectTopup(request.requestId);
      _toast('Demann lan refize.');
      _reload();
    } on ApiException catch (err) {
      _toast(err.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _newRequest() async {
    final staff = await UsersApi.instance.list();
    if (!mounted) return;

    final amountCtrl = TextEditingController();
    String? targetUid = staff.isNotEmpty ? staff.first.uid : null;

    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nouvo rechaj'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: targetUid,
                decoration: const InputDecoration(labelText: 'Staff'),
                items: staff
                    .map((member) => DropdownMenuItem(
                          value: member.uid,
                          child: Text('${member.label} (${member.role})'),
                        ))
                    .toList(),
                onChanged: (value) => setDialogState(() => targetUid = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Montan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Anile'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kreye'),
            ),
          ],
        ),
      ),
    );

    if (created != true || targetUid == null) return;

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.').trim());
    if (amount == null || amount <= 0) {
      _toast('Montan an pa valid.');
      return;
    }

    try {
      await WalletApi.instance.requestTopup(
        targetUid: targetUid!,
        amount: amount,
      );
      _toast('Demann lan kreye.');
      _reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Topup approval',
      children: [
        const DashboardHero(
          icon: Icons.fact_check_outlined,
          title: 'Rechaj wallet',
          subtitle: 'Apwouve oswa refize demann rechaj staff yo.',
        ),
        const SizedBox(height: 18),
        DashboardActionTile(
          icon: Icons.add_card_outlined,
          title: 'Nouvo rechaj',
          subtitle: 'Kreye yon demann pou yon staff',
          onTap: _busy ? () {} : _newRequest,
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: FutureBuilder<List<TopupRequest>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                final error = snap.error;
                return Text(
                  error is ApiException ? error.message : '$error',
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                );
              }

              final requests = snap.data ?? const <TopupRequest>[];
              if (requests.isEmpty) {
                return const Text('Pa gen demann rechaj.');
              }

              return Column(
                children: requests
                    .map((request) => _TopupRow(
                          request: request,
                          busy: _busy,
                          onApprove: () => _approve(request),
                          onReject: () => _reject(request),
                        ))
                    .toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TopupRow extends StatelessWidget {
  const _TopupRow({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final TopupRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.targetName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: DashboardColors.ink,
                  ),
                ),
              ),
              Text(
                '${request.amount.toStringAsFixed(2)} ${request.currency}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: DashboardColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Estati: ${request.status}'
            '${request.requestedByName.isEmpty ? '' : ' • mande pa ${request.requestedByName}'}',
            style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
          ),
          if (request.isPending) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : onApprove,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Apwouve'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Refize'),
                ),
              ],
            ),
          ],
          const Divider(height: 20),
        ],
      ),
    );
  }
}
