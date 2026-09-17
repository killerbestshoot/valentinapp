import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/payment_error_view.dart';

import '../../data/airtime_gateway_provider.dart';
import '../../domain/airtime_gateway.dart';
import '../../domain/airtime_models.dart';

/// Livre yon tranzaksyon Minit Haiti POU VRE atravè Reloadly.
///
/// Menm wòl ak `BazikDeliveryDialog` pou MonCash/NatCash: se Reloadly ki
/// konfime, pa yon klik "Delivered". Devi a parèt anvan: operatè, sa
/// benefisyè a resevwa, sa wallet la peye.
class AirtimeDeliveryDialog extends StatefulWidget {
  const AirtimeDeliveryDialog({
    super.key,
    required this.txId,
    required this.amount,
    required this.currency,
    required this.phone,
    this.clientName = '',
    this.gateway,
  });

  final String txId;
  final double amount;
  final String currency;
  final String phone;
  final String clientName;
  final AirtimeGateway? gateway;

  /// Retounen `true` si minit yo pati.
  static Future<bool> show(
    BuildContext context, {
    required String txId,
    required double amount,
    required String currency,
    required String phone,
    String clientName = '',
    AirtimeGateway? gateway,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AirtimeDeliveryDialog(
        txId: txId,
        amount: amount,
        currency: currency,
        phone: phone,
        clientName: clientName,
        gateway: gateway,
      ),
    );

    return result ?? false;
  }

  @override
  State<AirtimeDeliveryDialog> createState() => _AirtimeDeliveryDialogState();
}

class _AirtimeDeliveryDialogState extends State<AirtimeDeliveryDialog> {
  AirtimeGateway get _gateway => widget.gateway ?? AirtimeGatewayProvider.instance;

  AirtimeQuote? _quote;
  AirtimeTopup? _result;
  PaymentException? _error;
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
        phone: widget.phone,
        amount: widget.amount,
        currency: widget.currency,
      );
      if (mounted) setState(() => _quote = quote);
    } on PaymentException catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deliver() async {
    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final topup = await _gateway.deliver(
        txId: widget.txId,
        operatorId: _quote?.operator.operatorId,
      );
      if (mounted) setState(() => _result = topup);
    } on PaymentException catch (err) {
      if (mounted) setState(() => _error = err);
    } catch (err) {
      if (mounted) setState(() => _error = PaymentException('unexpected', '$err'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _refresh() async {
    final current = _result;
    if (current == null) return;

    setState(() => _sending = true);
    try {
      final topup = await _gateway.refresh(current.topupId);
      if (mounted) setState(() => _result = topup);
    } on PaymentException catch (err) {
      if (mounted) setState(() => _error = err);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final done = result != null && result.status == AirtimeTopupStatus.completed;

    return AlertDialog(
      title: const Text('Voye minit (Reloadly)'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.clientName.isEmpty ? 'Kliyan' : widget.clientName} · ${widget.phone}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Row(
                  children: [
                    SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('N ap chèche operatè a...'),
                  ],
                ),
              if (_quote != null && result == null) AirtimeQuoteSummary(quote: _quote!),
              if (result != null) AirtimeResultSummary(topup: result),
              if (_error != null) ...[
                const SizedBox(height: 12),
                PaymentErrorView(error: _error!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(done),
          child: Text(result == null ? 'Anile' : 'Fèmen'),
        ),
        if (result == null)
          FilledButton.icon(
            onPressed: _quote == null || _sending ? null : _deliver,
            icon: _sending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.phone_android_outlined),
            label: const Text('Voye minit yo'),
          ),
        if (result != null && result.status == AirtimeTopupStatus.processing)
          FilledButton.icon(
            onPressed: _sending ? null : _refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Verifye estati a'),
          ),
      ],
    );
  }
}

/// Operatè, sa benefisyè a resevwa, sa wallet la peye.
class AirtimeQuoteSummary extends StatelessWidget {
  const AirtimeQuoteSummary({super.key, required this.quote});

  final AirtimeQuote quote;

  @override
  Widget build(BuildContext context) {
    final operator = quote.operator;
    final range = operator.isFixed
        ? operator.fixedAmounts.map((a) => a.toStringAsFixed(2)).join(' · ')
        : '${operator.minAmount.toStringAsFixed(2)} – ${operator.maxAmount.toStringAsFixed(2)}';
    final ratesDay = quote.ratesUpdatedAt == null
        ? ''
        : DateTime.fromMillisecondsSinceEpoch(quote.ratesUpdatedAt!, isUtc: true)
            .toIso8601String()
            .substring(0, 10);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        children: [
          _Line(label: 'Operatè', value: operator.name),
          _Line(label: 'Nimewo', value: quote.phone),
          if (quote.isConverted) ...[
            _Line(
              label: 'Kliyan an peye',
              value: '${quote.amount.toStringAsFixed(2)} ${quote.currency}',
            ),
            _Line(
              label: 'Voye bay Reloadly',
              value: '${quote.sendAmount.toStringAsFixed(2)} ${quote.sendCurrency}',
            ),
          ],
          _Line(
            label: 'Benefisyè a resevwa (estimasyon)',
            value: '${quote.estimatedDelivered.toStringAsFixed(2)} ${quote.deliveredCurrency}',
          ),
          _Line(
            label: 'Montan aksepte',
            value: '$range ${quote.useLocalAmount ? quote.currency : operator.senderCurrency}',
          ),
          const Divider(height: 18),
          _Line(
            label: 'Total nan wallet ou',
            value: '${quote.debit.toStringAsFixed(2)} ${quote.debitCurrency}',
            bold: true,
          ),
          if (quote.isConverted)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'To${ratesDay.isEmpty ? '' : ' $ratesDay'}: 1 ${quote.currency} = '
                '${quote.conversionRate.toStringAsFixed(4)} ${quote.sendCurrency}'
                '${quote.ratesStale ? ' — ⚠️ to a pa ajou' : ''}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF667365)),
              ),
            ),
          if (quote.mode != 'live')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                quote.mode == 'fake'
                    ? 'MÒD SIMILASYON: okenn minit p ap pati vre.'
                    : 'SANDBOX: okenn vre minit p ap pati.',
                style: const TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rezilta yon rechaj.
class AirtimeResultSummary extends StatelessWidget {
  const AirtimeResultSummary({super.key, required this.topup});

  final AirtimeTopup topup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (color, icon, title) = switch (topup.status) {
      AirtimeTopupStatus.completed => (
          scheme.primaryContainer,
          Icons.check_circle_outline,
          'Minit yo pati',
        ),
      AirtimeTopupStatus.failed => (
          scheme.errorContainer,
          Icons.cancel_outlined,
          'Rechaj la pa pase',
        ),
      AirtimeTopupStatus.processing => (
          scheme.secondaryContainer,
          Icons.hourglass_top_outlined,
          'An verifikasyon — pa voye l ankò',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${topup.operatorName} · ${topup.phone}'),
          if (topup.status == AirtimeTopupStatus.completed)
            Text(
              'Livre: ${(topup.delivered > 0 ? topup.delivered : topup.estimatedDelivered).toStringAsFixed(2)} '
              '${topup.deliveredCurrency}',
            ),
          SelectableText('Referans: ${topup.topupId}'),
          SelectableText(
            topup.gatewayId.isEmpty
                ? 'ID Reloadly: — (poko konfime)'
                : 'ID Reloadly: ${topup.gatewayId}',
          ),
          if (topup.status == AirtimeTopupStatus.failed && topup.refunded)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Wallet ou ranbouse otomatikman.'),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
      color: bold ? const Color(0xFF172116) : const Color(0xFF667365),
      fontSize: bold ? 15 : 13,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Flexible(child: Text(value, style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}
