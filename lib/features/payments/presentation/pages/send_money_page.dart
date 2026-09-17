import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/payment_gateway_provider.dart';
import '../../domain/payment_gateway.dart';
import '../../domain/payment_models.dart';
import '../widgets/payment_error_view.dart';

/// Voye lajan sou MonCash / NatCash atravè Bazik.
///
/// Prensip UI a: ajan an wè EGZAKTEMAN sa k ap soti nan wallet li (montan +
/// frè 5%) anvan li konfime. Se pou sa `quote` la parèt an dirèk.
class SendMoneyPage extends StatefulWidget {
  const SendMoneyPage({
    super.key,
    this.gateway,
    this.kind = 'payout',
    this.txId = '',
  });

  final PaymentGateway? gateway;

  /// 'payout' (voye bay yon staff) oswa 'delivery' (livre yon tranzaksyon).
  final String kind;
  final String txId;

  @override
  State<SendMoneyPage> createState() => _SendMoneyPageState();
}

class _SendMoneyPageState extends State<SendMoneyPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _receiverController = TextEditingController();
  final _noteController = TextEditingController();

  PaymentNetwork _network = PaymentNetwork.moncash;
  TransferQuote? _quote;
  WalletBalance? _balance;
  Transfer? _result;
  GatewayStatus? _gatewayStatus;

  bool _sending = false;
  bool _quoting = false;
  PaymentException? _error;
  Timer? _quoteDebounce;

  /// Kle idempotans fòmilè a.
  ///
  /// Li RETE MENM tan fòmilè a pa voye avèk siksè: yon doub-klik oswa yon
  /// "Eseye ankò" apre yon timeout reyitilize l, donk serveur a rekonèt menm
  /// transfè a olye li voye lajan an de fwa. Li chanje sèlman apre yon siksè,
  /// pou pwochen transfè a vin yon lòt transfè.
  String _idempotencySeed = _newSeed();

  static String _newSeed() =>
      'send:${DateTime.now().microsecondsSinceEpoch}:${identityHashCode(Object())}';

  PaymentGateway get _gateway => widget.gateway ?? PaymentGatewayProvider.instance;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_scheduleQuote);
    _loadBalance();
    _loadGatewayStatus();
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _amountController.dispose();
    _phoneController.dispose();
    _receiverController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final balance = await _gateway.wallet();
      if (mounted) setState(() => _balance = balance);
    } on PaymentException {
      // Sld la se yon konfò: si li pa chaje, paj la dwe travay kanmenm.
    }
  }

  /// Avèti ajan an AVAN li tape yon montan si transfè a p ap ka rive.
  Future<void> _loadGatewayStatus() async {
    try {
      final status = await _gateway.status();
      if (mounted) setState(() => _gatewayStatus = status);
    } on PaymentException {
      // Si nou pa ka li eta a, nou pa bloke paj la: Bazik rete otorite a.
    }
  }

  /// Nou pa rele serveur a sou chak lèt: nou tann 400ms.
  void _scheduleQuote() {
    _quoteDebounce?.cancel();
    _quoteDebounce = Timer(const Duration(milliseconds: 400), _refreshQuote);
  }

  Future<void> _refreshQuote() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      if (mounted) setState(() => _quote = null);
      return;
    }

    setState(() => _quoting = true);

    try {
      final quote = await _gateway.quote(amount: amount, network: _network);
      if (mounted) setState(() => _quote = quote);
    } on PaymentException catch (err) {
      if (mounted) setState(() => _quote = null);
      if (mounted && err.isUserFixable) setState(() => _error = err);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sending = true;
      _error = null;
      _result = null;
    });

    try {
      final transfer = await _gateway.send(
        amount: double.parse(_amountController.text.trim()),
        network: _network,
        phone: _phoneController.text.trim(),
        receiverName: _receiverController.text.trim(),
        note: _noteController.text.trim(),
        kind: widget.kind,
        txId: widget.txId,
        idempotencySeed: widget.txId.isEmpty ? _idempotencySeed : null,
      );

      if (!mounted) return;
      setState(() {
        _result = transfer;
        // Siksè: pwochen transfè a se yon lòt transfè.
        if (transfer.status != TransferStatus.failed) {
          _idempotencySeed = _newSeed();
        }
      });
      await _loadBalance();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voye lajan'),
        actions: [
          if (_balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_balance!.balance.toStringAsFixed(2)} ${_balance!.currency}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_gatewayStatus != null && !_gatewayStatus!.canSend) ...[
                _GatewayBanner(status: _gatewayStatus!),
                const SizedBox(height: 16),
              ],
              SegmentedButton<PaymentNetwork>(
                segments: const [
                  ButtonSegment(value: PaymentNetwork.moncash, label: Text('MonCash')),
                  ButtonSegment(value: PaymentNetwork.natcash, label: Text('NatCash')),
                ],
                selected: {_network},
                onSelectionChanged: (selection) {
                  setState(() => _network = selection.first);
                  _refreshQuote();
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montan',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final amount = double.tryParse((value ?? '').trim());
                  if (amount == null || amount <= 0) return 'Antre yon montan valid.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nimewo benefisyè a',
                  hintText: '+509 3712 3456',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                  final local = digits.startsWith('509') ? digits.substring(3) : digits;
                  if (local.length != 8) return 'Nimewo a dwe gen 8 chif.';
                  return null;
                },
              ),
              if (_network.requiresReceiverName) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _receiverController,
                  decoration: const InputDecoration(
                    labelText: 'Non konplè benefisyè a',
                    helperText: 'NatCash mande non ak siyati.',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!_network.requiresReceiverName) return null;
                    final parts = (value ?? '').trim().split(RegExp(r'\s+'));
                    if (parts.length < 2 || parts.first.isEmpty) {
                      return 'Antre non ak siyati.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Nòt (opsyonèl)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              _QuoteCard(quote: _quote, loading: _quoting, network: _network),
              if (_error != null) ...[
                const SizedBox(height: 12),
                PaymentErrorView(error: _error!, onRetry: _send),
              ],
              if (_result != null) ...[
                const SizedBox(height: 12),
                _ResultCard(transfer: _result!),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Voye'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Montre ajan an sa k ap soti nan wallet li, frè yo ladan.
class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote, required this.loading, required this.network});

  final TransferQuote? quote;
  final bool loading;
  final PaymentNetwork network;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Card(
        child: ListTile(
          leading: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('N ap kalkile frè yo...'),
        ),
      );
    }

    if (quote == null) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(
            'Minimòm ${network.label}: ${network.minimumHtg.toStringAsFixed(0)} HTG',
          ),
          subtitle: const Text('Antre yon montan pou wè frè yo.'),
        ),
      );
    }

    final quoted = quote!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _QuoteRow(
              label: 'Benefisyè a resevwa',
              value: '${quoted.amountHtg.toStringAsFixed(2)} HTG',
            ),
            _QuoteRow(
              label: 'Frè Bazik (${quoted.feePercent.toStringAsFixed(0)}%)',
              value: '${quoted.feeHtg.toStringAsFixed(2)} HTG',
            ),
            const Divider(),
            _QuoteRow(
              label: 'Total nan wallet ou',
              value: '${quoted.debit.toStringAsFixed(2)} ${quoted.walletCurrency}',
              bold: true,
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'To: 1 ${quoted.currency} = ${quoted.rateToHtg.toStringAsFixed(2)} HTG',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.label, required this.value, this.bold = false});

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.transfer});

  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final failed = transfer.status == TransferStatus.failed;

    return Card(
      color: failed
          ? Theme.of(context).colorScheme.errorContainer
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(failed ? Icons.cancel_outlined : Icons.check_circle_outline),
                const SizedBox(width: 8),
                Text(
                  failed ? 'Transfè a pa pase' : 'Transfè a pati',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Referans: ${transfer.reference}'),
            Text('Estati: ${transfer.status.name}'),
            // Vid = transfè a pa janm rive sou Bazik.
            Text(
              transfer.gatewayId.isEmpty
                  ? 'ID Bazik: — (transfè a pa rive sou Bazik)'
                  : 'ID Bazik: ${transfer.gatewayId}',
            ),
            if (failed && transfer.refunded)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Wallet ou ranbouse otomatikman.'),
              ),
            if (failed && transfer.failureReason.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(transfer.failureReason),
              ),
          ],
        ),
      ),
    );
  }
}


/// Di klèman poukisa yon transfè p ap parèt sou dashboard Bazik la.
class _GatewayBanner extends StatelessWidget {
  const _GatewayBanner({required this.status});

  final GatewayStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final title = !status.reachesBazik
        ? 'Mòd similasyon'
        : 'Kont Bazik la san pwovizyon';

    final detail = !status.reachesBazik
        ? 'Transfè yo rete lokal: yo p ap parèt sou dashboard Bazik la.'
        : 'Float la: ${status.available.toStringAsFixed(2)} ${status.currency}. '
            'Bazik ap refize chak transfè jiskaske yo chaje kont lan.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.tertiary),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(detail, style: TextStyle(color: scheme.onTertiaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
