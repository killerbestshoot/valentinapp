import 'package:mon_premye_app/features/payments/domain/payment_models.dart';

import '../domain/airtime_gateway.dart';
import '../domain/airtime_models.dart';

/// Tranzaksyon Minit jan serveur a konnen l (montan, deviz, nimewo).
class FakeAirtimeTransaction {
  const FakeAirtimeTransaction({
    required this.phone,
    required this.amount,
    this.currency = 'USD',
  });

  final String phone;
  final double amount;
  final String currency;
}

/// Minit Haiti an memwa: tès widget ak mòd `MOCK_FIREBASE=true`.
///
/// Li kopye règ serveur a (`reloadly/src/airtime.js`): operatè pa prefiks,
/// limit RANGE, deviz wallet obligatwa, yon sèl rechaj pa tranzaksyon.
/// Limit ak to yo se sa sandbox Reloadly a te bay le 17/09/2026.
class FakeAirtimeGateway implements AirtimeGateway {
  FakeAirtimeGateway({
    this.walletCurrency = 'USD',
    this.failingPhones = const {'37000000'},
    this.enabled = true,
    this.ratesToHtg = const {'HTG': 1, 'USD': 132, 'MXN': 7.25, 'DOP': 2.25, 'CLP': 0.14, 'BRL': 24},
  });

  final String walletCurrency;

  /// "HTG pou 1 inite", menm fòm ak `exchange_rates` sou serveur a.
  final Map<String, double> ratesToHtg;
  final Set<String> failingPhones;
  final bool enabled;

  /// Tès yo mete tranzaksyon yo la (sa `POST /api/transactions` ta kreye).
  final Map<String, FakeAirtimeTransaction> transactions = {};

  /// Chak rechaj livre, pa tranzaksyon.
  final Map<String, AirtimeTopup> delivered = {};

  final List<String> quotedPhones = [];

  static const _natcomPrefixes = {'32', '33', '35', '40', '41', '42', '43', '44', '55'};

  String _local(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final local = digits.length == 11 && digits.startsWith('509')
        ? digits.substring(3)
        : digits;

    if (local.length != 8) {
      throw PaymentException(
        'invalid_phone',
        'Nimewo a pa valid: $phone. Nou tann yon nimewo Ayiti ak 8 chif.',
      );
    }
    return local;
  }

  void _assertEnabled() {
    if (!enabled) {
      throw const PaymentException(
        'airtime_unavailable',
        'Minit Haiti poko aktive: kle Reloadly yo pa konfigire sou serveur a.',
      );
    }
  }

  AirtimeOperator _operatorFor(String local) {
    if (!RegExp(r'^[345]').hasMatch(local)) {
      throw PaymentException(
        'operator_not_found',
        'Nou pa jwenn operatè nimewo +509$local la.',
      );
    }

    final natcom = _natcomPrefixes.contains(local.substring(0, 2));
    return natcom
        ? const AirtimeOperator(
            operatorId: 174,
            name: 'Natcom Haiti',
            fxRate: 131,
            minAmount: 0.5,
            maxAmount: 99.24,
          )
        : const AirtimeOperator(
            operatorId: 173,
            name: 'Digicel Haiti',
            fxRate: 121.46,
            minAmount: 4,
            maxAmount: 100,
          );
  }

  AirtimeQuote _quote(String phone, double amount, String? currency) {
    _assertEnabled();
    final local = _local(phone);
    final operator = _operatorFor(local);

    // Menm règ ak serveur a: nenpòt deviz konvèti an USD (awondi an BA),
    // debi a nan deviz wallet la (o pi pre).
    final amountCurrency = (currency ?? walletCurrency).toUpperCase();
    final rate = (ratesToHtg[amountCurrency] ?? 0) / (ratesToHtg[operator.senderCurrency] ?? 1);
    if (rate <= 0) {
      throw PaymentException('missing_rate', 'Pa gen exchange rate pou $amountCurrency -> HTG.');
    }
    final converted = amountCurrency != operator.senderCurrency;
    final sendAmount = converted ? (amount * rate * 100 + 1e-9).floorToDouble() / 100 : amount;
    final walletRate = (ratesToHtg[amountCurrency] ?? 0) / (ratesToHtg[walletCurrency] ?? 1);
    final debit = amountCurrency == walletCurrency ? amount : (amount * walletRate * 100).roundToDouble() / 100;

    if (sendAmount < operator.minAmount) {
      throw PaymentException(
        'amount_too_low',
        'Minimòm ${operator.name} se ${operator.minAmount.toStringAsFixed(2)} $walletCurrency.',
      );
    }
    if (sendAmount > operator.maxAmount) {
      throw PaymentException(
        'amount_too_high',
        'Maksimòm ${operator.name} se ${operator.maxAmount.toStringAsFixed(2)} $walletCurrency.',
      );
    }

    return AirtimeQuote(
      phone: '+509$local',
      operator: operator,
      currency: amountCurrency,
      amount: amount,
      sendAmount: sendAmount,
      sendCurrency: operator.senderCurrency,
      conversionRate: converted ? rate : 1,
      estimatedDelivered: sendAmount * operator.fxRate,
      deliveredCurrency: 'HTG',
      debit: debit,
      debitCurrency: walletCurrency,
      mode: 'fake',
    );
  }

  @override
  Future<AirtimeServiceStatus> status() async {
    return AirtimeServiceStatus(
      mode: 'fake',
      enabled: enabled,
      reachesReloadly: false,
    );
  }

  @override
  Future<AirtimeQuote> quote({
    required String phone,
    required double amount,
    String? currency,
    int? operatorId,
  }) async {
    quotedPhones.add(phone);
    return _quote(phone, amount, currency);
  }

  @override
  Future<AirtimeTopup> deliver({required String txId, int? operatorId}) async {
    final existing = delivered[txId];
    if (existing != null) return existing;

    final tx = transactions[txId];
    if (tx == null) {
      throw const PaymentException('transaction_not_found', 'Tranzaksyon an pa egziste.');
    }

    final quote = _quote(tx.phone, tx.amount, tx.currency);
    final failed = failingPhones.contains(_local(tx.phone));

    final topup = AirtimeTopup(
      topupId: 'AIR_fake_${delivered.length + 1}',
      status: failed ? AirtimeTopupStatus.failed : AirtimeTopupStatus.completed,
      amount: tx.amount,
      currency: quote.currency,
      operatorName: quote.operator.name,
      phone: quote.phone,
      estimatedDelivered: quote.estimatedDelivered,
      delivered: failed ? 0 : quote.estimatedDelivered,
      gatewayId: failed ? '' : '${10000 + delivered.length + 1}',
      refunded: failed,
      failureReason: failed ? 'transaction_cannot_be_processed_at_the_moment' : '',
    );

    delivered[txId] = topup;
    return topup;
  }

  @override
  Future<AirtimeTopup> refresh(String topupId) async {
    return delivered.values.firstWhere(
      (topup) => topup.topupId == topupId,
      orElse: () => throw const PaymentException(
        'airtime_topup_not_found',
        'Rechaj la pa egziste.',
      ),
    );
  }
}
