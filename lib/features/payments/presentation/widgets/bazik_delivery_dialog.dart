import 'package:flutter/material.dart';

import '../../data/payment_gateway_provider.dart';
import '../../domain/payment_gateway.dart';
import '../../domain/payment_models.dart';
import 'payment_error_view.dart';

/// Livre yon tranzaksyon POU VRE atravè Bazik.
///
/// Diferans ak bouton "Delivered" la: bouton sa a te sèlman chanje yon chan nan
/// Firestore. Yon moun te deklare livrezon an ak men l, epi komisyon yo t ap
/// kalkile sou yon livrezon pèsonn pa t verifye.
///
/// Isit la se Bazik ki konfime. Si li refize (pwovizyon, montan, nimewo),
/// erè a parèt tèl kèl ak sa pou fè — se sa `PaymentErrorView` bay.
class BazikDeliveryDialog extends StatefulWidget {
  const BazikDeliveryDialog({
    super.key,
    required this.txId,
    required this.amount,
    required this.currency,
    required this.phone,
    required this.serviceName,
    this.clientName = '',
    this.gateway,
  });

  final String txId;
  final double amount;
  final String currency;
  final String phone;
  final String serviceName;
  final String clientName;
  final PaymentGateway? gateway;

  /// Retounen `true` si transfè a pati.
  static Future<bool> show(
    BuildContext context, {
    required String txId,
    required double amount,
    required String currency,
    required String phone,
    required String serviceName,
    String clientName = '',
    PaymentGateway? gateway,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BazikDeliveryDialog(
        txId: txId,
        amount: amount,
        currency: currency,
        phone: phone,
        serviceName: serviceName,
        clientName: clientName,
        gateway: gateway,
      ),
    );

    return result ?? false;
  }

  @override
  State<BazikDeliveryDialog> createState() => _BazikDeliveryDialogState();
}

class _BazikDeliveryDialogState extends State<BazikDeliveryDialog> {
  PaymentGateway get _gateway =>
      widget.gateway ?? PaymentGatewayProvider.instance;

  /// Rezo a soti nan non sèvis la ki nan tranzaksyon an.
  PaymentNetwork get _network =>
      PaymentNetworkX.forServiceName(widget.serviceName) ??
      PaymentNetwork.moncash;

  TransferQuote? _quote;
  PaymentException? _error;
  Transfer? _result;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadQuote();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final quote = await _gateway.quote(
        amount: widget.amount,
        network: _network,
        currency: widget.currency,
      );
      if (mounted) setState(() => _quote = quote);
    } on PaymentException catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final transfer = await _gateway.send(
        amount: widget.amount,
        network: _network,
        phone: widget.phone,
        receiverName: widget.clientName,
        kind: 'delivery',
        txId: widget.txId,
        currency: widget.currency,
        // Menm tranzaksyon => menm seed => yon sèl transfè, menm si moun nan
        // klike de fwa.
        idempotencySeed: 'tx:${widget.txId}',
        note: 'Livrezon ${widget.serviceName}',
      );

      if (!mounted) return;
      setState(() => _result = transfer);
    } on PaymentException catch (err) {
      if (mounted) setState(() => _error = err);
    } catch (err) {
      if (mounted) {
        setState(() => _error = PaymentException('unexpected', '$err'));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Livre via ${_network.label}'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Row(label: 'Kliyan', value: widget.clientName.isEmpty ? '—' : widget.clientName),
              _Row(label: 'Nimewo', value: widget.phone),
              _Row(
                label: 'Montan',
                value: '${widget.amount.toStringAsFixed(2)} ${widget.currency}',
              ),
              const Divider(height: 24),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('N ap kalkile frè yo...'),
                    ],
                  ),
                ),

              if (_quote != null && _result == null) ...[
                _Row(
                  label: 'Benefisyè a resevwa',
                  value: '${_quote!.amountHtg.toStringAsFixed(2)} HTG',
                ),
                _Row(
                  label: 'Frè Bazik (${_quote!.feePercent.toStringAsFixed(0)}%)',
                  value: '${_quote!.feeHtg.toStringAsFixed(2)} HTG',
                ),
                _Row(
                  label: 'Total nan wallet ou',
                  value: '${_quote!.debit.toStringAsFixed(2)} ${_quote!.walletCurrency}',
                  bold: true,
                ),
              ],

              if (_result != null) ...[
                const SizedBox(height: 4),
                Text(
                  _result!.status == TransferStatus.failed
                      ? 'Transfè a pa pase.'
                      : 'Transfè a pati.',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                _Row(label: 'Referans', value: _result!.reference),
                _Row(
                  label: 'ID Bazik',
                  value: _result!.gatewayId.isEmpty
                      ? '— (pa rive sou Bazik)'
                      : _result!.gatewayId,
                ),
                if (_result!.refunded)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Wallet la ranbouse otomatikman.'),
                  ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                PaymentErrorView(error: _error!, onRetry: _send),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, _result != null),
          child: Text(_result != null ? 'Fèmen' : 'Anile'),
        ),
        if (_result == null)
          FilledButton(
            onPressed: (_sending || _loading || _quote == null) ? null : _send,
            child: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Voye lajan an'),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w900) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF667365), fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: style)),
        ],
      ),
    );
  }
}
