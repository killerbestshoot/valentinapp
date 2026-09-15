import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/bazik_delivery_dialog.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Jesyon tranzaksyon yo: wè, livre, chanje estati, efase.
///
/// "Livre via Bazik" se vre livrezon an — se konfimasyon Bazik ki fè
/// tranzaksyon an vin `delivered`, epi se sa ki deklanche komisyon yo.
/// Bouton "Make manyèl" la rete pou ka livrezon an fèt an kach.
class TransactionManagementPage extends StatefulWidget {
  const TransactionManagementPage({super.key});

  @override
  State<TransactionManagementPage> createState() =>
      _TransactionManagementPageState();
}

class _TransactionManagementPageState extends State<TransactionManagementPage> {
  late Future<List<TransactionRecord>> _future;
  String _statusFilter = '';

  static const _filters = ['', 'pending', 'delivered', 'failed'];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<TransactionRecord>> _load() {
    return TransactionApi.instance.list(
      limit: 50,
      status: _statusFilter.isEmpty ? null : _statusFilter,
    );
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
    final sent = await BazikDeliveryDialog.show(
      context,
      txId: tx.txId,
      amount: tx.amount,
      currency: tx.currency,
      phone: tx.customerPhone,
      serviceName: tx.serviceName,
      clientName: tx.customerName,
    );

    if (sent) _reload();
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
          child: Row(
            children: [
              const Text(
                'Estati: ',
                style: TextStyle(color: DashboardColors.muted),
              ),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _statusFilter,
                  underline: const SizedBox.shrink(),
                  items: _filters
                      .map((value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.isEmpty ? 'Tout' : value),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() => _statusFilter = value ?? '');
                    _reload();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Rafrechi',
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
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
                return const Text('Pa gen tranzaksyon.');
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
              FilledButton.icon(
                onPressed: tx.isDelivered ? null : onDeliver,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: const Text('Livre via Bazik'),
              ),
              OutlinedButton.icon(
                onPressed: onMarkDelivered,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Make manyèl'),
              ),
              OutlinedButton.icon(
                onPressed: onMarkPending,
                icon: const Icon(Icons.pending_actions, size: 18),
                label: const Text('Pending'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB91C1C),
                ),
                onPressed: onDelete,
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
