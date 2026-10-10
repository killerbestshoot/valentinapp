import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mon_premye_app/core/format/haiti_phone.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
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
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/pages/receipts/receipt_page.dart';

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
  final amountCtrl = TextEditingController();

  String serviceName = 'MonCash';

  /// Kiyès ki peye frè platfòm nan. Frè a li menm soti nan règ owner a.
  FeeMode _feeMode = FeeMode.sender;

  /// Devi frè a (serveur a): frè, sa benefisyè a resevwa, sa kliyan an peye.
  FeeQuote? _feeQuote;
  String? _feeError;
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

  /// Wallet ajan an, to jounen an, ak dènye benefisyè li yo. Yo se yon konfò:
  /// si youn pa chaje, fòm nan rete itilizab.
  WalletSummary? _wallet;
  Map<String, double> _rates = const {};
  List<TransactionRecord> _favorites = const [];

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
    _loadContext();
  }

  Future<void> _loadContext() async {
    try {
      final wallet = await WalletApi.instance.mine();
      if (mounted) setState(() => _wallet = wallet);
    } catch (_) {}
    try {
      final rates = await WalletApi.instance.rates();
      if (mounted) setState(() => _rates = rates);
    } catch (_) {}
    try {
      final recent = await TransactionApi.instance.list(limit: 40);
      final seen = <String>{};
      final favorites = <TransactionRecord>[];
      for (final tx in recent) {
        final key = HaitiPhone.localPart(tx.customerPhone);
        if (key.isEmpty || tx.customerName.trim().isEmpty || !seen.add(key)) continue;
        favorites.add(tx);
        if (favorites.length == 6) break;
      }
      if (mounted) setState(() => _favorites = favorites);
    } catch (_) {}
  }

  /// Yon favori: ranpli benefisyè a ak sèvis la, montan an rete pou ajan an.
  void _useFavorite(TransactionRecord tx) {
    setState(() {
      nameCtrl.text = tx.customerName.trim();
      phoneCtrl.text = HaitiPhone.localPart(tx.customerPhone);
      if (services.contains(tx.serviceName)) serviceName = tx.serviceName;
    });
    _refreshQuote();
  }

  void _selectService(String service) {
    if (loading || service == serviceName) return;
    setState(() => serviceName = service);
    _refreshQuote();
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    nameCtrl.dispose();
    phoneCtrl.dispose();
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

    if (amount <= 0) {
      if (mounted) {
        setState(() {
          _feeQuote = null;
          _feeError = null;
          _quote = null;
          _airtimeQuote = null;
          _quoteError = null;
        });
      }
      return;
    }

    setState(() => _quoting = true);

    try {
      // 1) Frè platfòm nan, pou TOUT sèvis: se li ki di konbyen benefisyè a
      //    resevwa (si frè a dedwi) ak konbyen kliyan an peye.
      final fee = await _fetchFeeQuote(amount);

      // 2) Devi pasrèl la sou sa benefisyè a resevwa vre (minimòm NatCash,
      //    operatè minit...).
      final ready = _deliversAutomatically && (!_isAirtimeService || _hasHaitiPhone);
      if (ready) {
        await _fetchQuote(fee.netAmount);
      } else if (mounted) {
        setState(() {
          _quote = null;
          _airtimeQuote = null;
        });
      }
      if (mounted) setState(() => _quoteError = null);
    } on ApiException catch (err) {
      if (mounted) {
        setState(() {
          _feeQuote = null;
          _feeError = err.message;
          _quote = null;
          _airtimeQuote = null;
        });
      }
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

  Future<FeeQuote> _fetchFeeQuote(double amount) async {
    final fee = await TransactionApi.instance.quote(
      serviceName: serviceName,
      amount: amount,
      currency: paymentCurrency,
      feeMode: _feeMode,
    );
    if (mounted) {
      setState(() {
        _feeQuote = fee;
        _feeError = null;
      });
    }
    return fee;
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
      final fee = await _fetchFeeQuote(amount);
      if (_deliversAutomatically) {
        await _fetchQuote(fee.netAmount);
      }

      // Serveur a mete `enterpriseId` ak `staffUid` pou kont li, depi sesyon
      // an — yon kliyan pa ka atribiye yon tranzaksyon bay yon lòt antrepriz.
      final created = await TransactionApi.instance.create(
        serviceName: serviceName,
        customerName: name,
        customerPhone: phone,
        // `amount` se sa ajan an tape. Serveur a kalkile frè a, epi selon
        // `feeMode` li ajoute l sou montan an oswa li retire l ladan.
        amount: amount,
        currency: paymentCurrency,
        feeMode: _feeMode,
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
        // Sa benefisyè a resevwa (frè a deja retire si l dedwi). Serveur a
        // pran montan an nan tranzaksyon an kanmenm.
        amount: created.amount,
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
    } on ApiException catch (err) {
      if (mounted) setState(() => _error = PaymentException(err.code, err.message));
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
    amountCtrl.clear();
    setState(() {
      _feeQuote = null;
      _feeError = null;
      _quote = null;
      _airtimeQuote = null;
      _quoteError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        foregroundColor: _ink,
        title: const Text(
          'Nouvo tranzaksyon',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          if (_wallet != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _WalletChip(wallet: _wallet!),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final steps = _buildSteps();
            final ticket = _buildTicket();

            return Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(isWide ? 28 : 16, 8, isWide ? 28 : 16, 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 14, child: steps),
                                const SizedBox(width: 20),
                                Expanded(flex: 10, child: ticket),
                              ],
                            )
                          : Column(children: [steps, const SizedBox(height: 16), ticket]),
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

  // --- Etap yo (agoch) ---

  Widget _buildSteps() {
    final phoneOk = HaitiPhone.localPart(phoneCtrl.text).length == HaitiPhone.localDigits;
    final benefOk = nameCtrl.text.trim().isNotEmpty && phoneOk;
    final amountOk = _num(amountCtrl.text) > 0 && _feeError == null && _quoteError == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepCard(
          number: 1,
          title: 'Sèvis',
          hint: 'Ki jan benefisyè a ap resevwa',
          done: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(builder: (context, box) {
                final narrow = box.maxWidth < 460;
                final cards = services
                    .map((name) => _ServiceCard(
                          key: ValueKey('service-$name'),
                          name: name,
                          selected: name == serviceName,
                          onTap: () => _selectService(name),
                        ))
                    .toList();
                return narrow
                    ? Column(children: [
                        for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 8), child: c),
                      ])
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var k = 0; k < cards.length; k++) ...[
                            if (k > 0) const SizedBox(width: 10),
                            Expanded(child: cards[k]),
                          ],
                        ],
                      );
              }),
              if (PaymentNetworkX.forServiceName(serviceName) == PaymentNetwork.natcash) ...[
                const SizedBox(height: 10),
                NetworkMinimumNotice(network: PaymentNetwork.natcash, currency: paymentCurrency),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StepCard(
          number: 2,
          title: 'Benefisyè',
          hint: _favorites.isEmpty ? '' : 'Peze yon favori pou ranpli',
          done: benefOk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_favorites.isNotEmpty) ...[
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, k) => _FavoriteChip(
                      tx: _favorites[k],
                      onTap: loading ? null : () => _useFavorite(_favorites[k]),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              LayoutBuilder(builder: (context, box) {
                final name = TextFormField(
                  controller: nameCtrl,
                  enabled: !loading,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(label: 'Non benefisyè', icon: Icons.person_outline),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Non benefisyè a obligatwa.' : null,
                  onChanged: (_) => setState(() {}),
                );
                final phone = TextFormField(
                  controller: phoneCtrl,
                  enabled: !loading,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  // Prefiks la se yon bagay app la konnen, se pa yon bagay ajan an
                  // tape. Formatè a retire l tou si moun nan kole yon nimewo konplè.
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
                );
                if (box.maxWidth < 520) {
                  return Column(children: [name, const SizedBox(height: 12), phone]);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [Expanded(child: name), const SizedBox(width: 12), Expanded(child: phone)],
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _StepCard(
          number: 3,
          title: 'Montan',
          hint: '',
          done: amountOk,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: amountCtrl,
                      enabled: !loading,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _ink),
                      decoration: _inputDecoration(label: 'Montan', icon: Icons.payments_outlined),
                      validator: (value) => _num(value ?? '') <= 0 ? 'Mete yon montan ki valid.' : null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 120,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      // Nenpòt deviz, pou tout sèvis: serveur a konvèti ak to
                      // jounen an, debi a fèt nan deviz wallet la.
                      initialValue: paymentCurrency,
                      decoration: _inputDecoration(label: 'Deviz'),
                      items: currencies
                          .map((currency) => DropdownMenuItem(value: currency, child: Text(currency)))
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
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: (_quickAmounts[paymentCurrency] ?? const <double>[])
                    .map((v) => ActionChip(
                          label: Text('${_m(v, decimals: 0)} $paymentCurrency'),
                          onPressed: loading
                              ? null
                              : () {
                                  amountCtrl.text = v.toStringAsFixed(0);
                                  setState(() {});
                                },
                        ))
                    .toList(),
              ),
              if (paymentCurrency != 'HTG' && (_rates[paymentCurrency] ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'To jodi a: 1 $paymentCurrency = ${_m(_rates[paymentCurrency]!)} HTG',
                  style: const TextStyle(color: _muted, fontSize: 12.5),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Frè a', style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 8),
              SegmentedButton<FeeMode>(
                segments: const [
                  ButtonSegment(
                    value: FeeMode.sender,
                    icon: Icon(Icons.add_circle_outline),
                    label: Text('Kliyan an peye l anplis'),
                  ),
                  ButtonSegment(
                    value: FeeMode.deducted,
                    icon: Icon(Icons.remove_circle_outline),
                    label: Text('Dedwi sou montan an'),
                  ),
                ],
                selected: {_feeMode},
                showSelectedIcon: false,
                onSelectionChanged: loading
                    ? null
                    : (v) {
                        setState(() => _feeMode = v.first);
                        _refreshQuote();
                      },
              ),
              const SizedBox(height: 6),
              Text(
                _feeMode == FeeMode.sender
                    ? 'Benefisyè a resevwa tout montan an; frè a ajoute sou sa kliyan an peye.'
                    : 'Kliyan an bay montan an; frè a retire ladan l, benefisyè a resevwa mwens.',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _quickAmounts = <String, List<double>>{
    'MXN': [500, 1000, 2000, 5000],
    'USD': [50, 100, 200, 500],
    'DOP': [2000, 5000, 10000],
    'CLP': [50000, 100000, 200000],
    'BRL': [200, 500, 1000],
    'HTG': [1000, 2500, 5000, 10000],
  };

  // --- Tikè a (adwat) ---

  Widget _buildTicket() {
    final q = _feeQuote;
    final htg = _isAirtimeService ? null : _quote?.amountHtg;
    final debit = q?.walletDebit ?? _quote?.debit;
    final debitCurrency = q?.walletCurrency ?? _quote?.walletCurrency;
    final hasResult = _sent != null || _delivered != null || _savedTxId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PayCard(
          quote: q,
          loading: _quoting && q == null,
          error: _feeError,
          receiverName: nameCtrl.text,
          amountHtg: htg,
        ),
        if (q != null || debit != null) ...[
          const SizedBox(height: 12),
          _AccountCard(
            quote: q,
            wallet: _wallet,
            debit: debit,
            debitCurrency: debitCurrency,
          ),
        ],
        if (_isAirtimeService && _airtimeQuote != null) ...[
          const SizedBox(height: 12),
          AirtimeQuoteSummary(quote: _airtimeQuote!),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: loading ? null : save,
          style: FilledButton.styleFrom(
            backgroundColor: _brand,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Icon(_deliversAutomatically ? Icons.send_outlined : Icons.save_outlined),
          label: Text(
            loading
                ? (_deliversAutomatically ? 'Ap voye...' : 'Ap anrejistre...')
                : (_deliversAutomatically ? 'Anrejistre epi voye' : 'Anrejistre transaction'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Yon sèl klik. Si transfè a pa pase, wallet ou ranbouse otomatikman.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12),
        ),
        if (_quoteError != null && _error == null) ...[
          const SizedBox(height: 14),
          PaymentErrorView(error: _quoteError!),
        ],
        if (_error != null) ...[
          const SizedBox(height: 14),
          PaymentErrorView(error: _error!, onRetry: save),
        ],
        if (_sent != null) ...[
          const SizedBox(height: 14),
          _SentPanel(transfer: _sent!),
        ],
        if (_delivered != null) ...[
          const SizedBox(height: 14),
          AirtimeResultSummary(topup: _delivered!),
        ],
        if (_sent == null && _delivered == null && _error == null && _savedTxId != null) ...[
          const SizedBox(height: 14),
          _SavedPanel(txId: _savedTxId!),
        ],
        if (hasResult && _savedTxId != null && _error == null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ReceiptPage(transactionId: _savedTxId!)),
            ),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Wè ak pataje resi a'),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? prefixText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
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

// ---------------------------------------------------------------------------
// Moso ekran an
// ---------------------------------------------------------------------------

const _cInk = Color(0xFF172116);
const _cMuted = Color(0xFF667365);
const _cBrand = Color(0xFF123D2B);
const _cLine = Color(0xFFDDE8D8);
const _cSoft = Color(0xFFEEF4EA);

/// 12 345,67 — menm fòma ak resi a.
String _m(double v, {int decimals = 2}) {
  final parts = v.abs().toStringAsFixed(decimals).split('.');
  final d = parts[0];
  final b = StringBuffer();
  for (var i = 0; i < d.length; i++) {
    if (i > 0 && (d.length - i) % 3 == 0) b.write(' ');
    b.write(d[i]);
  }
  return '${v < 0 ? '−' : ''}$b${parts.length > 1 ? ',${parts[1]}' : ''}';
}

const _serviceStyle = {
  'MonCash': ('M', Color(0xFFC8102E), 'Digicel · min 100 HTG'),
  'NatCash': ('N', Color(0xFF0B5FA5), 'Natcom · min 3 998 HTG'),
  'Minit Haiti': ('%', Color(0xFF6B4FA0), 'Rechaj Digicel ak Natcom'),
};

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.hint,
    required this.done,
    required this.child,
  });

  final int number;
  final String title;
  final String hint;
  final bool done;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: done ? const Color(0xFF15803D) : _cSoft, shape: BoxShape.circle),
                child: done
                    ? const Icon(Icons.check, size: 15, color: Colors.white)
                    : Text('$number', style: const TextStyle(fontWeight: FontWeight.w900, color: _cBrand, fontSize: 12)),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _cInk)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(hint,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _cMuted, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({super.key, required this.name, required this.selected, required this.onTap});

  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (letter, color, subtitle) = _serviceStyle[name] ?? ('?', _cBrand, '');
    return Material(
      color: selected ? _cSoft : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _cBrand : _cLine, width: selected ? 1.8 : 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9)),
                child: Text(letter,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: _cInk)),
                    Text(subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: _cMuted)),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle, size: 18, color: _cBrand),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteChip extends StatelessWidget {
  const _FavoriteChip({required this.tx, required this.onTap});

  final TransactionRecord tx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (_, color, _) = _serviceStyle[tx.serviceName] ?? ('?', _cBrand, '');
    final digits = HaitiPhone.localPart(tx.customerPhone);
    final masked = digits.length == 8 ? '${digits.substring(0, 2)} •• •• ${digits.substring(6)}' : digits;
    final initials = tx.customerName
        .trim()
        .split(RegExp(r'[\s-]+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(5, 5, 14, 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _cLine),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: Text(initials,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.customerName.trim(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  Text('${tx.serviceName} · $masked', style: const TextStyle(fontSize: 11, color: _cMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletChip extends StatelessWidget {
  const _WalletChip({required this.wallet});

  final WalletSummary wallet;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _cBrand, borderRadius: BorderRadius.circular(10)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WALLET ${wallet.currency}',
              style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
          Text(_m(wallet.balance), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Sa kliyan an peye — gwo chif ajan an di kliyan an byen fò.
class _PayCard extends StatelessWidget {
  const _PayCard({
    required this.quote,
    required this.loading,
    required this.error,
    required this.receiverName,
    this.amountHtg,
  });

  final FeeQuote? quote;
  final bool loading;
  final String? error;
  final String receiverName;
  final double? amountHtg;

  @override
  Widget build(BuildContext context) {
    final q = quote;
    final who = receiverName.trim().isEmpty ? 'Benefisyè a' : receiverName.trim();

    Widget body;
    if (error != null) {
      body = Text(error!, style: const TextStyle(color: Color(0xFFFFD7D7), fontWeight: FontWeight.w700));
    } else if (loading) {
      body = const Row(children: [
        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 10),
        Text('N ap kalkile frè a...', style: TextStyle(color: Colors.white)),
      ]);
    } else if (q == null) {
      body = const Text('Chwazi sèvis la, benefisyè a ak montan an: total la parèt isit la.',
          style: TextStyle(color: Colors.white70));
    } else {
      final pct = q.feePct == q.feePct.roundToDouble() ? q.feePct.toStringAsFixed(0) : q.feePct.toStringAsFixed(1);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(TextSpan(children: [
              TextSpan(
                text: _m(q.totalPaid),
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              TextSpan(text: ' ${q.currency}', style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ])),
          ),
          const Text('Di kliyan an chif sa a byen fò anvan ou peze bouton an.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          _TicketLine(label: '$who resevwa', value: '${_m(q.netAmount)} ${q.currency}', light: true),
          if (amountHtg != null) _TicketLine(label: 'An goud', value: '${_m(amountHtg!)} HTG', light: true),
          _TicketLine(
            label: q.minApplied ? 'Frè (minimòm)' : 'Frè $pct%',
            value: q.feeMode == FeeMode.deducted ? '− ${_m(q.fee)} ${q.currency}' : '+ ${_m(q.fee)} ${q.currency}',
            light: true,
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _cBrand, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('KLIYAN AN PEYE AN TOU',
              style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.9)),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }
}

/// Sa ki soti nan wallet ajan an ak komisyon li — kliyan an pa wè sa.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.quote, required this.wallet, this.debit, this.debitCurrency});

  final FeeQuote? quote;
  final WalletSummary? wallet;
  final double? debit;
  final String? debitCurrency;

  @override
  Widget build(BuildContext context) {
    final after = wallet != null && debit != null && wallet!.currency == debitCurrency ? wallet!.balance - debit! : null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(children: [
            Expanded(child: Text('Sou kont ou', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
            Text('Kliyan an pa wè sa', style: TextStyle(color: _cMuted, fontSize: 11.5)),
          ]),
          const SizedBox(height: 8),
          if (debit != null)
            _TicketLine(label: 'Total nan wallet ou', value: '${_m(debit!)} ${debitCurrency ?? ''}', bold: true),
          if (after != null)
            _TicketLine(
              label: after < 0 ? 'Sòld ou pa ase' : 'Wallet apre',
              value: '${_m(after)} ${wallet!.currency}',
              danger: after < 0,
            ),
          if (quote != null)
            _TicketLine(
              label: 'Komisyon ou lè l livre',
              value: '+ ${_m(quote!.agentCommission)} ${quote!.currency}',
              good: true,
            ),
        ],
      ),
    );
  }
}

class _TicketLine extends StatelessWidget {
  const _TicketLine({
    required this.label,
    required this.value,
    this.light = false,
    this.bold = false,
    this.good = false,
    this.danger = false,
  });

  final String label;
  final String value;
  final bool light;
  final bool bold;
  final bool good;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final labelColor = light ? Colors.white70 : _cMuted;
    final valueColor = light
        ? Colors.white
        : danger
            ? const Color(0xFFB91C1C)
            : good
                ? const Color(0xFF15803D)
                : _cInk;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: light ? Colors.white24 : _cLine)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: labelColor, fontSize: 13))),
          Text(value,
              style: TextStyle(color: valueColor, fontSize: 13, fontWeight: bold || good ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}
