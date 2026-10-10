import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/realtime/realtime.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/airtime/domain/airtime_models.dart';
import 'package:mon_premye_app/features/airtime/presentation/widgets/airtime_delivery_dialog.dart';
import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/bazik_delivery_dialog.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Jesyon tranzaksyon yo: wè, livre, chanje estati, efase.
///
/// "Livre via Bazik" (MonCash/NatCash) ak "Voye minit" (Minit Haiti, Reloadly)
/// se vre livrezon yo — se konfimasyon pasrèl la ki fè tranzaksyon an vin
/// `delivered`, epi se sa ki deklanche komisyon yo. Bouton "Make manyèl" la
/// rete pou ka livrezon an fèt an kach.
class TransactionManagementPage extends StatefulWidget {
  const TransactionManagementPage({super.key});

  @override
  State<TransactionManagementPage> createState() =>
      _TransactionManagementPageState();
}

class _TransactionManagementPageState extends State<TransactionManagementPage> {
  late Future<List<TransactionRecord>> _future;
  String _statusFilter = '';
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  /// Estati serveur a ↔ sa ajan an li.
  static const _filters = {
    '': 'Tout',
    'pending': 'An atant',
    'sending': 'Ap voye',
    'delivered': 'Livre',
    'failed': 'Echwe',
    'canceled': 'Anile',
  };

  StreamSubscription<RealtimeEvent>? _live;

  @override
  void initState() {
    super.initState();
    _future = _load();
    // Yon tranzaksyon kreye oswa livre (menm pa yon lòt moun) parèt touswit.
    _live = Realtime.instance.listen(const {'transactions', 'transfers'}, _reload);
  }

  @override
  void dispose() {
    _live?.cancel();
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<List<TransactionRecord>> _load() {
    return TransactionApi.instance.list(
      limit: 100,
      status: _statusFilter.isEmpty ? null : _statusFilter,
      search: _searchCtrl.text,
    );
  }

  /// Rechèch la pati 350 ms apre dènye lèt la, pa sou chak lèt.
  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _reload);
    setState(() {});
  }

  void _reload() {
    // Apre yon `await`, ekran an ka deja fèmen.
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setStatus(TransactionRecord tx, String status) async {
    try {
      await TransactionApi.instance.updateStatus(tx.txId, status);
      _toast('Estati mete: $status');
      _reload();
    } on ApiException catch (err) {
      _toast(err.message);
    }
  }

  Future<void> _delete(TransactionRecord tx) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Efase tranzaksyon an?'),
            content: Text('${tx.serviceName} — ${tx.customerName}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Anile'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                ),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Efase'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    try {
      await TransactionApi.instance.remove(tx.txId);
      _toast('Tranzaksyon efase.');
      _reload();
    } on ApiException catch (err) {
      // Sèl owner ki ka efase: serveur a di sa klèman.
      _toast(err.message);
    }
  }

  Future<void> _deliver(TransactionRecord tx) async {
    final Future<bool> dialog;

    switch (DeliveryChannel.forService(tx.serviceName)) {
      case DeliveryChannel.bazik:
        dialog = BazikDeliveryDialog.show(
          context,
          txId: tx.txId,
          amount: tx.amount,
          currency: tx.currency,
          phone: tx.customerPhone,
          serviceName: tx.serviceName,
          clientName: tx.customerName,
        );
      case DeliveryChannel.reloadly:
        dialog = AirtimeDeliveryDialog.show(
          context,
          txId: tx.txId,
          amount: tx.amount,
          currency: tx.currency,
          phone: tx.customerPhone,
          clientName: tx.customerName,
        );
      case DeliveryChannel.manual:
        return;
    }

    if (await dialog) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Transactions',
      children: [
        const DashboardHero(
          icon: Icons.receipt_long_outlined,
          title: 'Tranzaksyon yo',
          subtitle: 'Swiv, livre ak jere tranzaksyon antrepriz la.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _reload(),
                      decoration: InputDecoration(
                        hintText: 'Chèche pa non, nimewo oswa referans',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Efase rechèch la',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _searchDebounce?.cancel();
                                  _reload();
                                },
                              ),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Rafrechi',
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filters.entries
                    .map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _statusFilter == e.key,
                          showCheckmark: false,
                          onSelected: (_) {
                            setState(() => _statusFilter = e.key);
                            _reload();
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: FutureBuilder<List<TransactionRecord>>(
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

              final transactions = snap.data ?? const <TransactionRecord>[];
              if (transactions.isEmpty) {
                final filtered = _statusFilter.isNotEmpty || _searchCtrl.text.trim().isNotEmpty;
                return Text(filtered
                    ? 'Okenn tranzaksyon pa koresponn ak filtre sa yo.'
                    : 'Pa gen tranzaksyon.');
              }

              return Column(
                children: transactions
                    .map((tx) => _TransactionRow(
                          tx: tx,
                          onDeliver: () => _deliver(tx),
                          onMarkDelivered: () => _setStatus(tx, 'delivered'),
                          onMarkPending: () => _setStatus(tx, 'pending'),
                          onDelete: () => _delete(tx),
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.tx,
    required this.onDeliver,
    required this.onMarkDelivered,
    required this.onMarkPending,
    required this.onDelete,
  });

  final TransactionRecord tx;
  final VoidCallback onDeliver;
  final VoidCallback onMarkDelivered;
  final VoidCallback onMarkPending;
  final VoidCallback onDelete;

  Color get _statusColor {
    switch (tx.status) {
      case 'delivered':
        return const Color(0xFF15803D);
      case 'failed':
      case 'canceled':
        return const Color(0xFFB91C1C);
      default:
        return const Color(0xFFB45309);
    }
  }

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
                  '${tx.serviceName} — ${tx.customerName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: DashboardColors.ink,
                  ),
                ),
              ),
              Text(
                '${tx.amount.toStringAsFixed(2)} ${tx.currency}',
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tx.status,
                  style: TextStyle(
                    color: _statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tx.customerPhone,
                  style: const TextStyle(
                    color: DashboardColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Pa gen bouton pasrèl pou WU/CAM: anvan, "Livre via Bazik"
              // te parèt sou TOUT tranzaksyon yo, e dyalòg la te tonbe sou
              // MonCash pou yon sèvis li pa konnen — yon vant minit te ka voye
              // vre goud MonCash bay kliyan an.
              if (DeliveryChannel.forService(tx.serviceName) ==
                  DeliveryChannel.bazik)
                FilledButton.icon(
                  onPressed: tx.isDelivered ? null : onDeliver,
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Livre via Bazik'),
                ),
              if (DeliveryChannel.forService(tx.serviceName) ==
                  DeliveryChannel.reloadly)
                FilledButton.icon(
                  onPressed: tx.isDelivered ? null : onDeliver,
                  icon: const Icon(Icons.phone_android_outlined, size: 18),
                  label: const Text('Voye minit'),
                ),
              // Yon tranzaksyon livre FÈMEN: komisyon yo peye, lajan an pati.
              // Serveur a refize (409) — bouton yo dezaktive pou di sa davans.
              OutlinedButton.icon(
                onPressed: tx.isDelivered ? null : onMarkDelivered,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Make manyèl'),
              ),
              OutlinedButton.icon(
                onPressed: tx.isDelivered ? null : onMarkPending,
                icon: const Icon(Icons.pending_actions, size: 18),
                label: const Text('Pending'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                ),
                onPressed: tx.isDelivered ? null : onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Efase'),
              ),
            ],
          ),
          const Divider(height: 24),
        ],
      ),
    );
  }
}

/// Ki pasrèl ki livre yon sèvis.
enum DeliveryChannel {
  /// MonCash, NatCash.
  bazik,

  /// Minit Haiti.
  reloadly,

  /// Western Union, CAM...: livrezon fizik, "Make manyèl" sèlman.
  manual;

  static DeliveryChannel forService(String serviceName) {
    if (PaymentNetworkX.forServiceName(serviceName) != null) return bazik;
    if (isAirtimeServiceName(serviceName)) return reloadly;
    return manual;
  }
}
