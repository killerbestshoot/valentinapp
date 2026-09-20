import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/format/haiti_phone.dart';
import 'package:mon_premye_app/features/airtime/data/airtime_gateway_provider.dart';
import 'package:mon_premye_app/features/airtime/domain/airtime_gateway.dart';
import 'package:mon_premye_app/features/airtime/domain/airtime_models.dart';
import 'package:mon_premye_app/features/airtime/presentation/widgets/airtime_delivery_dialog.dart';
import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/data/payment_gateway_provider.dart';
import 'package:mon_premye_app/features/payments/domain/payment_gateway.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/network_minimum_notice.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/payment_error_view.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  static const _ink = Color(0xFF172116);
  static const _muted = Color(0xFF667365);
  static const _surface = Color(0xFFF4F8F1);
  static const _brand = Color(0xFF123D2B);

  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final feeCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  String serviceName = 'MonCash';
  String paymentCurrency = 'MXN';
  bool loading = false;

  /// Devi a parèt pandan ajan an ap tape: li wè konbyen sa koute AVAN li
  /// peze. Se pa yon kesyon — se enfòmasyon.
  TransferQuote? _quote;
  bool _quoting = false;
  Timer? _quoteDebounce;

  /// Devi Minit Haiti (operatè + sa benefisyè a resevwa).
  AirtimeQuote? _airtimeQuote;

  /// Yon erè devi ajan an ka korije (montan anba minimòm NatCash, nimewo,
  /// deviz...). Li parèt PANDAN l ap tape, pa apre li fin anrejistre.
  PaymentException? _quoteError;

  /// Rezilta dènye voye a.
  Transfer? _sent;
  AirtimeTopup? _delivered;
  PaymentException? _error;
  String? _savedTxId;

  PaymentGateway get _gateway => PaymentGatewayProvider.instance;
  AirtimeGateway get _airtime => AirtimeGatewayProvider.instance;

  final services = const ['MonCash', 'NatCash', 'Minit Haiti'];
  final currencies = const ['MXN', 'USD', 'DOP', 'CLP', 'BRL', 'HTG'];

  @override
  void initState() {
    super.initState();
    amountCtrl.addListener(_scheduleQuote);
    // Devi Minit Haiti a depann de nimewo a (se li ki bay operatè a).
    phoneCtrl.addListener(_scheduleQuote);
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    nameCtrl.dispose();
    phoneCtrl.dispose();
    feeCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  double _num(String v) => double.tryParse(v.replaceAll(',', '.').trim()) ?? 0;

  /// Èske sèvis la ka livre pa Bazik? (WU ak CAM livre fizikman.)
  bool get _isGatewayService =>
      PaymentNetworkX.forServiceName(serviceName) != null;

  /// Minit Haiti: livre pa Reloadly.
  bool get _isAirtimeService => isAirtimeServiceName(serviceName);

  /// Sèvis ki livre otomatikman apre anrejistreman (Bazik oswa Reloadly).
  bool get _deliversAutomatically => _isGatewayService || _isAirtimeService;

  bool get _hasHaitiPhone => HaitiPhone.isValid(phoneCtrl.text);

  /// Devi an dirèk, ak yon ti delè pou nou pa rele serveur a sou chak lèt.
  void _scheduleQuote() {
    _quoteDebounce?.cancel();
    _quoteDebounce = Timer(const Duration(milliseconds: 400), _refreshQuote);
  }

  Future<void> _refreshQuote() async {
    final amount = _num(amountCtrl.text);
    final ready = _deliversAutomatically &&
        amount > 0 &&
        (!_isAirtimeService || _hasHaitiPhone);

    if (!ready) {
      if (mounted) {
        setState(() {
          _quote = null;
          _airtimeQuote = null;
          _quoteError = null;
        });
      }
      return;
    }

    setState(() => _quoting = true);

    try {
      await _fetchQuote(amount);
      if (mounted) setState(() => _quoteError = null);
    } on PaymentException catch (err) {
      // Devi a se yon konfò: si li echwe pou yon rezon teknik, fòm nan rete
      // itilizab. Men yon erè ajan an KA korije (montan anba minimòm NatCash,
      // nimewo, operatè) dwe parèt kounye a. Anvan, li te disparèt an silans:
      // ajan an peze, tranzaksyon an te kreye, EPI voye a te echwe apre.
      if (mounted) {
        setState(() {
          _quote = null;
          _airtimeQuote = null;
          _quoteError = err.isUserFixable ? err : null;
        });
      }
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  /// Rele devi ki koresponn ak sèvis la. Erè a monte bay moun k ap rele a.
  Future<void> _fetchQuote(double amount) async {
    if (_isAirtimeService) {
      final quote = await _airtime.quote(
        phone: HaitiPhone.international(phoneCtrl.text),
        amount: amount,
        currency: paymentCurrency,
      );
      if (mounted) {
        setState(() {
          _airtimeQuote = quote;
          _quote = null;
        });
      }
      return;
    }

    final quote = await _gateway.quote(
      amount: amount,
      network: PaymentNetworkX.forServiceName(serviceName)!,
      currency: paymentCurrency,
    );
    if (mounted) {
      setState(() {
        _quote = quote;
        _airtimeQuote = null;
      });
    }
  }



  /// Anrejistre EPI voye, san okenn kesyon.
  ///
  /// Lòd la enpòtan: tras la ekri anvan nou touche lajan. Si voye a echwe,
  /// tranzaksyon an egziste toujou (an `pending`) e erè a parèt anba fòm nan —
  /// men nou pa poze okenn kesyon ni mande okenn konfimasyon.
  Future<void> save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final name = nameCtrl.text.trim();
    final phone = HaitiPhone.international(phoneCtrl.text);
    final amount = _num(amountCtrl.text);

    setState(() {
      loading = true;
      _error = null;
      _quoteError = null;
      _sent = null;
      _delivered = null;
      _savedTxId = null;
    });

    try {
      // VERIFYE ANVAN NOU KREYE TRANZAKSYON AN.
      //
      // Devi a pase pa MENM validasyon ak voye a (minimòm NatCash 3 998 HTG,
      // limit operatè, deviz wallet, kont Reloadly). Si li refize, nou
      // kanpe la: pa gen tranzaksyon `pending` òfelen ki rete dèyè yon voye
      // ki pa t ka janm pase. Devi an dirèk la ka pa t gen tan fini (debounce):
      // se poutèt sa nou rele l ankò isit la, e nou tann li.
      if (_deliversAutomatically) {
        await _fetchQuote(amount);
      }

      // Serveur a mete `enterpriseId` ak `staffUid` pou kont li, depi sesyon
      // an — yon kliyan pa ka atribiye yon tranzaksyon bay yon lòt antrepriz.
      final created = await TransactionApi.instance.create(
        serviceName: serviceName,
        customerName: name,
        customerPhone: phone,
        // `amount` se sa benefisyè a resevwa. Frè a ajoute sou li pou sa
        // kliyan an peye — li pa retire nan sa ki pati.
        amount: amount,
        currency: paymentCurrency,
        senderFee: _num(feeCtrl.text),
      );

      final txId = created.txId;

      if (!mounted) return;
      setState(() => _savedTxId = txId);

      // Sèvis ki pa livre otomatikman (WU, CAM): yo livre yon lòt jan.
      if (!_deliversAutomatically) {
        _clearForm();
        return;
      }

      // Minit Haiti: serveur a pran montan ak nimewo a nan tranzaksyon an.
      // Menm tranzaksyon => menm rechaj, menm si moun nan peze de fwa.
      if (_isAirtimeService) {
        final topup = await _airtime.deliver(
          txId: txId,
          operatorId: _airtimeQuote?.operator.operatorId,
        );

        if (!mounted) return;
        setState(() => _delivered = topup);

        if (topup.status != AirtimeTopupStatus.failed) _clearForm();
        return;
      }

      // Voye tou swit. Menm tranzaksyon => menm seed => yon sèl transfè,
      // menm si moun nan peze de fwa.
      final transfer = await _gateway.send(
        amount: amount,
        network: PaymentNetworkX.forServiceName(serviceName)!,
        phone: phone,
        receiverName: name,
        kind: 'delivery',
        txId: txId,
        currency: paymentCurrency,
        idempotencySeed: 'tx:$txId',
        note: 'Livrezon $serviceName',
      );

      if (!mounted) return;
      setState(() => _sent = transfer);

      if (transfer.status != TransferStatus.failed) _clearForm();
    } on PaymentException catch (err) {
      if (mounted) setState(() => _error = err);
    } catch (e) {
      if (mounted) {
        setState(() => _error = PaymentException('unexpected', '$e'));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _clearForm() {
    nameCtrl.clear();
    phoneCtrl.clear();
    feeCtrl.clear();
    amountCtrl.clear();
    setState(() {
      _quote = null;
      _airtimeQuote = null;
      _quoteError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final amount = amountCtrl.text.trim();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        foregroundColor: _ink,
        centerTitle: true,
        title: const Text(
          'Nouvo transaction',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16,
                  12,
                  isWide ? 32 : 16,
                  32,
                ),
                children: [
                  _HeroBand(isWide: isWide),
                  const SizedBox(height: 18),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: _buildFormCard()),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 3,
                                  child: _SummaryCard(
                                    service: serviceName,
                                    customerName: nameCtrl.text,
                                    phone: phoneCtrl.text,
                                    amount: amount,
                                    currency: paymentCurrency,
                                    loading: loading,
                                    onSave: save,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _SummaryCard(
                                  service: serviceName,
                                  customerName: nameCtrl.text,
                                  phone: phoneCtrl.text,
                                  amount: amount,
                                  currency: paymentCurrency,
                                  loading: loading,
                                  onSave: save,
                                ),
                                const SizedBox(height: 18),
                                _buildFormCard(),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_outlined, color: _brand),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Detay transaction',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: serviceName,
            decoration: _inputDecoration(
              label: 'Service',
              icon: Icons.storefront_outlined,
            ),
            items: services
                .map((service) => DropdownMenuItem(
                      value: service,
                      child: Text(service),
                    ))
                .toList(),
            onChanged: loading
                ? null
                : (v) {
                    setState(() => serviceName = v ?? 'MonCash');
                    _refreshQuote();
                  },
          ),
          if (PaymentNetworkX.forServiceName(serviceName) ==
              PaymentNetwork.natcash) ...[
            const SizedBox(height: 10),
            NetworkMinimumNotice(
              network: PaymentNetwork.natcash,
              currency: paymentCurrency,
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: nameCtrl,
            enabled: !loading,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Non kliyan',
              icon: Icons.person_outline,
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Non kliyan obligatwa.';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phoneCtrl,
            enabled: !loading,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            // Prefiks la se yon bagay app la konnen, se pa yon bagay ajan an
            // tape. Formatè a retire l tou si moun nan kole yon nimewo
            // konplè.
            inputFormatters: const [HaitiPhoneInputFormatter()],
            decoration: _inputDecoration(
              label: 'Telefòn',
              icon: Icons.phone_outlined,
              prefixText: '+${HaitiPhone.code} ',
              helperText: '${HaitiPhone.localDigits} chif',
            ),
            validator: (value) {
              final digits = HaitiPhone.localPart(value ?? '');
              if (digits.isEmpty) return 'Telefòn obligatwa.';
              if (digits.length != HaitiPhone.localDigits) {
                return 'Nimewo a dwe gen ${HaitiPhone.localDigits} chif.';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: amountCtrl,
                  enabled: !loading,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    label: 'Montan',
                    icon: Icons.payments_outlined,
                  ),
                  validator: (value) {
                    if (_num(value ?? '') <= 0) {
                      return 'Mete yon montan ki valid.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  // Nenpòt deviz, pou tout sèvis: serveur a konvèti ak to
                  // jounen an (exchangerate-api), debi a fèt nan deviz wallet la.
                  initialValue: paymentCurrency,
                  decoration: _inputDecoration(
                    label: 'Deviz',
                    icon: Icons.attach_money,
                  ),
                  items: currencies
                      .map((currency) => DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          ))
                      .toList(),
                  onChanged: loading
                      ? null
                      : (v) {
                          setState(() => paymentCurrency = v ?? 'MXN');
                          _refreshQuote();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: feeCtrl,
            enabled: !loading,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            decoration: _inputDecoration(
              label: 'Frè kliyan an peye (opsyonèl)',
              icon: Icons.receipt_long_outlined,
              helperText: 'Kite l vid si kliyan an pa peye frè.',
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return null;
              if (_num(value ?? '') < 0) return 'Frè a pa ka negatif.';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          _ClientTotal(
            amount: _num(amountCtrl.text),
            fee: _num(feeCtrl.text),
            currency: paymentCurrency,
            receiverName: nameCtrl.text,
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: loading ? null : save,
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(_deliversAutomatically
                    ? Icons.send_outlined
                    : Icons.save_outlined),
            label: Text(
              loading
                  ? (_deliversAutomatically ? 'Ap voye...' : 'Ap anrejistre...')
                  : (_deliversAutomatically
                      ? 'Anrejistre epi voye'
                      : 'Anrejistre transaction'),
            ),
          ),
          if (!_isAirtimeService && (_quote != null || _quoting)) ...[
            const SizedBox(height: 16),
            _QuotePanel(quote: _quote, loading: _quoting),
          ],
          if (_isAirtimeService && _airtimeQuote != null) ...[
            const SizedBox(height: 16),
            AirtimeQuoteSummary(quote: _airtimeQuote!),
          ],
          if (_quoteError != null && _error == null) ...[
            const SizedBox(height: 16),
            PaymentErrorView(error: _quoteError!),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            PaymentErrorView(error: _error!, onRetry: save),
          ],
          if (_sent != null) ...[
            const SizedBox(height: 16),
            _SentPanel(transfer: _sent!),
          ],
          if (_delivered != null) ...[
            const SizedBox(height: 16),
            AirtimeResultSummary(topup: _delivered!),
          ],
          if (_sent == null &&
              _delivered == null &&
              _error == null &&
              _savedTxId != null) ...[
            const SizedBox(height: 16),
            _SavedPanel(txId: _savedTxId!),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? prefixText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      prefixText: prefixText,
      helperText: helperText,
      filled: true,
      fillColor: const Color(0xFFF9FCF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDDE8D8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDDE8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _brand, width: 1.5),
      ),
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Container(
          padding: EdgeInsets.all(isWide ? 28 : 20),
          decoration: BoxDecoration(
            color: _CreateTransactionPageState._brand,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_card_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kreye yon transaction',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ranpli enfòmasyon kliyan an, verifye rezime a, epi anrejistre.',
                      style: TextStyle(
                        color: Color(0xFFDDE8D8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.service,
    required this.customerName,
    required this.phone,
    required this.amount,
    required this.currency,
    required this.loading,
    required this.onSave,
  });

  final String service;
  final String customerName;
  final String phone;
  final String amount;
  final String currency;
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final displayAmount = amount.trim().isEmpty ? '0' : amount.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Rezime',
            style: TextStyle(
              color: _CreateTransactionPageState._ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8EE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Montan',
                  style: TextStyle(
                    color: _CreateTransactionPageState._muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$displayAmount $currency',
                  style: const TextStyle(
                    color: _CreateTransactionPageState._ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Service', value: service),
          _SummaryLine(
            label: 'Kliyan',
            value: customerName.trim().isEmpty
                ? 'Non pa antre'
                : customerName.trim(),
          ),
          _SummaryLine(
            label: 'Telefòn',
            value: phone.trim().isEmpty ? 'Telefòn pa antre' : phone.trim(),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: loading ? null : onSave,
            style: OutlinedButton.styleFrom(
              foregroundColor: _CreateTransactionPageState._brand,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Verifye & save'),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _CreateTransactionPageState._muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _CreateTransactionPageState._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Konbyen sa koute — parèt pandan ajan an ap tape.
///
/// Se pa yon konfimasyon: ajan an wè chif yo anvan li peze, epi li peze yon
/// sèl fwa. Nou pa poze okenn kesyon apre.
class _QuotePanel extends StatelessWidget {
  const _QuotePanel({required this.quote, required this.loading});

  final TransferQuote? quote;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading || quote == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F8F1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFDDE8D8)),
        ),
        child: const Row(
          children: [
            SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('N ap kalkile frè yo...'),
          ],
        ),
      );
    }

    final value = quote!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        children: [
          _QuoteLine(
            label: 'Benefisyè a resevwa',
            value: '${value.amountHtg.toStringAsFixed(2)} HTG',
          ),
          // Frè pasrèl la se depans ANTREPRIZ la, se pa frè kliyan an. Resi a
          // pa montre l: kliyan an wè sèlman sa li menm li peye.
          _QuoteLine(
            label: 'Frè pasrèl la (sou kont ou)',
            value: '${value.feeHtg.toStringAsFixed(2)} HTG',
          ),
          const Divider(height: 18),
          _QuoteLine(
            label: 'Total nan wallet ou',
            value: '${value.debit.toStringAsFixed(2)} ${value.walletCurrency}',
            bold: true,
          ),
        ],
      ),
    );
  }
}

/// Sa kliyan an peye, epi sa benefisyè a resevwa — de chif diferan depi gen frè.
///
/// Ajan an di sa a byen fò bay kliyan an anvan li peze bouton an. Si li rete
/// nan tèt ajan an sèlman, se la malantandi yo kòmanse.
class _ClientTotal extends StatelessWidget {
  const _ClientTotal({
    required this.amount,
    required this.fee,
    required this.currency,
    required this.receiverName,
  });

  final double amount;
  final double fee;
  final String currency;
  final String receiverName;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();

    final who = receiverName.trim().isEmpty ? 'Benefisyè a' : receiverName.trim();
    String money(double value) => '${value.toStringAsFixed(2)} $currency';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        children: [
          _QuoteLine(label: '$who resevwa', value: money(amount)),
          _QuoteLine(
            label: fee > 0 ? 'Frè kliyan an peye' : 'Frè',
            value: fee > 0 ? money(fee) : 'Pa gen frè',
          ),
          const Divider(height: 18),
          _QuoteLine(
            label: 'Kliyan an peye an tou',
            value: money(amount + fee),
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _QuoteLine extends StatelessWidget {
  const _QuoteLine({
    required this.label,
    required this.value,
    this.bold = false,
  });

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
          // Etikèt yo ka long (yo eksplike ki frè ki sou ki moun): san
          // `Expanded` la yo depase sou ti ekran.
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Rezilta yon transfè ki pati.
class _SentPanel extends StatelessWidget {
  const _SentPanel({required this.transfer});

  final Transfer transfer;

  @override
  Widget build(BuildContext context) {
    final failed = transfer.status == TransferStatus.failed;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: failed ? scheme.errorContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(failed ? Icons.cancel_outlined : Icons.check_circle_outline),
              const SizedBox(width: 8),
              Text(
                failed ? 'Transfè a pa pase' : 'Lajan an pati',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText('Referans: ${transfer.reference}'),
          // Vid = transfè a pa janm rive sou Bazik.
          SelectableText(
            transfer.gatewayId.isEmpty
                ? 'ID Bazik: — (pa rive sou Bazik)'
                : 'ID Bazik: ${transfer.gatewayId}',
          ),
          if (failed && transfer.refunded)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Wallet ou ranbouse otomatikman.'),
            ),
        ],
      ),
    );
  }
}

/// Sèvis ki pa livre otomatikman: tranzaksyon an anrejistre, livrezon an
/// fèt yon lòt jan (Western Union, CAM).
class _SavedPanel extends StatelessWidget {
  const _SavedPanel({required this.txId});

  final String txId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.inventory_2_outlined),
              SizedBox(width: 8),
              Text(
                'Tranzaksyon anrejistre',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText('ID: $txId'),
          const SizedBox(height: 4),
          const Text(
            'Sèvis sa a pa livre otomatikman: livrezon an fèt yon lòt jan.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
