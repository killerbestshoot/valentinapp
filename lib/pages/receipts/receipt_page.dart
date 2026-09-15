import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';

class ReceiptPage extends StatelessWidget {
  final String transactionId;

  const ReceiptPage({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF172116),
        centerTitle: true,
        title: const Text(
          'Resi transaction',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<TransactionRecord?>(
        future: TransactionApi.instance.find(transactionId),
        builder: (context, snap) {
          if (snap.hasError) {
            final error = snap.error;
            return _StateMessage(
              icon: Icons.error_outline,
              title: 'Erreur',
              message: error is ApiException ? error.message : '$error',
            );
          }

          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final tx = snap.data;

          if (tx == null) {
            return const _StateMessage(
              icon: Icons.receipt_long_outlined,
              title: 'Transaction pa jwenn',
              message: 'Nou pa jwenn resi sa a.',
            );
          }

          final service = tx.serviceName;
          final phone = tx.customerPhone;
          final amount = tx.amount.toStringAsFixed(2);
          final currency = tx.currency;
          final status = tx.status;
          final customerName = tx.customerName.trim().isEmpty
              ? 'Non pa disponib'
              : tx.customerName;

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 720;

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16,
                    12,
                    isWide ? 32 : 16,
                    32,
                  ),
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDDE8D8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 24,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding:
                                    const EdgeInsets.fromLTRB(24, 28, 24, 24),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF123D2B),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(8),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'VOUPVAPCASH',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Receipt / Resi',
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.78),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Montan',
                                                style: theme
                                                    .textTheme.labelLarge
                                                    ?.copyWith(
                                                  color:
                                                      const Color(0xFF667365),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                '$amount $currency'.trim(),
                                                style: theme
                                                    .textTheme.headlineMedium
                                                    ?.copyWith(
                                                  color:
                                                      const Color(0xFF172116),
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        _StatusPill(status: status),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    const Divider(height: 1),
                                    const SizedBox(height: 10),
                                    _ReceiptRow(
                                      icon: Icons.confirmation_number_outlined,
                                      label: 'ID',
                                      value: transactionId,
                                    ),
                                    _ReceiptRow(
                                      icon: Icons.storefront_outlined,
                                      label: 'Service',
                                      value: service,
                                    ),
                                    _ReceiptRow(
                                      icon: Icons.person_outline,
                                      label: 'Kliyan',
                                      value: customerName,
                                    ),
                                    _ReceiptRow(
                                      icon: Icons.phone_outlined,
                                      label: 'Telefòn',
                                      value: phone,
                                    ),
                                    _ReceiptRow(
                                      icon: Icons.payments_outlined,
                                      label: 'Montan',
                                      value: '$amount $currency'.trim(),
                                    ),
                                    const SizedBox(height: 18),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F8EE),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFFDDE8D8),
                                        ),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(
                                            Icons.verified_outlined,
                                            color: Color(0xFF2E7D32),
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Mèsi paske ou itilize VOUPVAPCASH.',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF263326),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          icon: const Icon(Icons.arrow_back),
                                          label: const Text('Retounen'),
                                        ),
                                        FilledButton.icon(
                                          onPressed: () => _copyReceipt(
                                            context,
                                            transactionId: transactionId,
                                            service: service,
                                            customerName: customerName,
                                            phone: phone,
                                            amount: amount,
                                            currency: currency,
                                            status: status,
                                          ),
                                          icon:
                                              const Icon(Icons.share_outlined),
                                          label: const Text('Pataje'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _copyReceipt(
    BuildContext context, {
    required String transactionId,
    required String service,
    required String customerName,
    required String phone,
    required String amount,
    required String currency,
    required String status,
  }) async {
    final receipt = [
      'VOUPVAPCASH - Receipt / Resi',
      'ID: $transactionId',
      'Service: $service',
      'Kliyan: $customerName',
      'Telefòn: $phone',
      'Montan: ${'$amount $currency'.trim()}',
      'Status: $status',
    ].join('\n');

    await Clipboard.setData(ClipboardData(text: receipt));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resi a kopye.')),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8EE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF667365),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  displayValue,
                  style: const TextStyle(
                    color: Color(0xFF172116),
                    fontSize: 15,
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final isDelivered = normalized == 'delivered' ||
        normalized == 'livre' ||
        normalized == 'livrée';
    final label = status.trim().isEmpty ? 'Pending' : status.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDelivered ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isDelivered ? const Color(0xFFA5D6A7) : const Color(0xFFFFECB3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDelivered ? Icons.check_circle_outline : Icons.schedule_outlined,
            size: 18,
            color:
                isDelivered ? const Color(0xFF2E7D32) : const Color(0xFFF57F17),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: isDelivered
                  ? const Color(0xFF1B5E20)
                  : const Color(0xFF7A5200),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: const Color(0xFF667365)),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667365)),
            ),
          ],
        ),
      ),
    );
  }
}
