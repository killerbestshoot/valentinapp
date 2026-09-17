/// Modèl domèn Minit Haiti (Reloadly Airtime).
///
/// Menm prensip ak `payment_models.dart`: okenn klas isit la pa konnen HTTP ni
/// Reloadly. Erè yo se `PaymentException`: `PaymentErrorView` konnen kòd yo.
library;

double _toDouble(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

List<double> _toDoubles(dynamic value) =>
    value is List ? value.map(_toDouble).toList() : const <double>[];

/// Sèvis katalòg la ki livre pa Reloadly ("Minit Haiti").
bool isAirtimeServiceName(String serviceName) =>
    serviceName.toLowerCase().contains('minit');

/// Operatè yon nimewo (Digicel, Natcom), ak limit li.
class AirtimeOperator {
  const AirtimeOperator({
    required this.operatorId,
    required this.name,
    this.denominationType = 'RANGE',
    this.senderCurrency = 'USD',
    this.destinationCurrency = 'HTG',
    this.supportsLocalAmounts = false,
    this.fxRate = 0,
    this.minAmount = 0,
    this.maxAmount = 0,
    this.localMinAmount = 0,
    this.localMaxAmount = 0,
    this.fixedAmounts = const [],
    this.localFixedAmounts = const [],
    this.suggestedAmounts = const [],
  });

  final int operatorId;
  final String name;

  /// 'RANGE' (nenpòt montan ant min ak max) oswa 'FIXED' (yon lis montan).
  final String denominationType;
  final String senderCurrency;
  final String destinationCurrency;
  final bool supportsLocalAmounts;

  /// Konbyen HTG pou 1 inite deviz voye a.
  final double fxRate;
  final double minAmount;
  final double maxAmount;
  final double localMinAmount;
  final double localMaxAmount;
  final List<double> fixedAmounts;
  final List<double> localFixedAmounts;
  final List<double> suggestedAmounts;

  bool get isFixed => denominationType.toUpperCase() == 'FIXED';

  factory AirtimeOperator.fromJson(Map<String, dynamic> json) {
    return AirtimeOperator(
      operatorId: _toDouble(json['operatorId']).round(),
      name: '${json['name'] ?? ''}',
      denominationType: '${json['denominationType'] ?? 'RANGE'}',
      senderCurrency: '${json['senderCurrency'] ?? 'USD'}',
      destinationCurrency: '${json['destinationCurrency'] ?? 'HTG'}',
      supportsLocalAmounts: json['supportsLocalAmounts'] == true,
      fxRate: _toDouble(json['fxRate']),
      minAmount: _toDouble(json['minAmount']),
      maxAmount: _toDouble(json['maxAmount']),
      localMinAmount: _toDouble(json['localMinAmount']),
      localMaxAmount: _toDouble(json['localMaxAmount']),
      fixedAmounts: _toDoubles(json['fixedAmounts']),
      localFixedAmounts: _toDoubles(json['localFixedAmounts']),
      suggestedAmounts: _toDoubles(json['suggestedAmounts']),
    );
  }
}

/// Sa ajan an ap peye ak sa benefisyè a ap resevwa, anvan li konfime.
class AirtimeQuote {
  const AirtimeQuote({
    required this.phone,
    required this.operator,
    required this.currency,
    required this.amount,
    required this.estimatedDelivered,
    required this.deliveredCurrency,
    required this.debit,
    this.useLocalAmount = false,
    double? sendAmount,
    String? sendCurrency,
    this.conversionRate = 1,
    String? debitCurrency,
    this.ratesUpdatedAt,
    this.ratesStale = false,
    this.mode = 'live',
  })  : sendAmount = sendAmount ?? amount,
        sendCurrency = sendCurrency ?? currency,
        debitCurrency = debitCurrency ?? currency;

  /// Fòma entènasyonal: +509XXXXXXXX.
  final String phone;
  final AirtimeOperator operator;

  /// Deviz MONTAN AN (sa kliyan an peye).
  final String currency;
  final double amount;
  final bool useLocalAmount;

  /// Sa serveur a voye bay Reloadly — konvèti si deviz la pa deviz operatè a.
  final double sendAmount;
  final String sendCurrency;

  /// Konbyen `sendCurrency` pou 1 `currency` (1 si pa gen konvèsyon).
  final double conversionRate;

  /// Deviz wallet ajan an, kote `debit` la fèt.
  final String debitCurrency;

  /// Dat to jounen an (ms). `null` si pa gen konvèsyon.
  final int? ratesUpdatedAt;
  final bool ratesStale;

  bool get isConverted => sendCurrency != currency && !useLocalAmount;

  /// Estimasyon: montan egzak la soti nan repons Reloadly a.
  final double estimatedDelivered;
  final String deliveredCurrency;

  /// Sa ki soti nan wallet la (pa gen frè sou minit).
  final double debit;

  /// 'fake' | 'sandbox' | 'live'
  final String mode;

  factory AirtimeQuote.fromJson(Map<String, dynamic> json) {
    return AirtimeQuote(
      phone: '${json['phone'] ?? ''}',
      operator: AirtimeOperator.fromJson(
        (json['operator'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      currency: '${json['currency'] ?? 'USD'}',
      amount: _toDouble(json['amount']),
      useLocalAmount: json['useLocalAmount'] == true,
      estimatedDelivered: _toDouble(json['estimatedDelivered']),
      deliveredCurrency: '${json['deliveredCurrency'] ?? 'HTG'}',
      debit: _toDouble(json['debit']),
      sendAmount: json['sendAmount'] == null ? null : _toDouble(json['sendAmount']),
      sendCurrency: json['sendCurrency'] == null ? null : '${json['sendCurrency']}',
      conversionRate: json['conversionRate'] == null ? 1 : _toDouble(json['conversionRate']),
      debitCurrency: json['debitCurrency'] == null ? null : '${json['debitCurrency']}',
      ratesUpdatedAt: json['ratesUpdatedAt'] is num ? (json['ratesUpdatedAt'] as num).toInt() : null,
      ratesStale: json['ratesStale'] == true,
      mode: '${json['mode'] ?? 'live'}',
    );
  }
}

enum AirtimeTopupStatus { processing, completed, failed }

AirtimeTopupStatus airtimeStatusFrom(String value) {
  switch (value.toLowerCase().trim()) {
    case 'completed':
      return AirtimeTopupStatus.completed;
    case 'failed':
      return AirtimeTopupStatus.failed;
    default:
      return AirtimeTopupStatus.processing;
  }
}

/// Yon rechaj minit.
class AirtimeTopup {
  const AirtimeTopup({
    required this.topupId,
    required this.status,
    required this.amount,
    required this.currency,
    this.operatorName = '',
    this.phone = '',
    this.estimatedDelivered = 0,
    this.delivered = 0,
    this.deliveredCurrency = 'HTG',
    this.gatewayId = '',
    this.refunded = false,
    this.failureReason = '',
  });

  final String topupId;
  final AirtimeTopupStatus status;
  final double amount;
  final String currency;
  final String operatorName;
  final String phone;
  final double estimatedDelivered;

  /// Sa Reloadly konfime li livre (0 tank li pa konfime).
  final double delivered;
  final String deliveredCurrency;

  /// ID tranzaksyon Reloadly a. Vid = Reloadly poko konfime anyen.
  final String gatewayId;
  final bool refunded;
  final String failureReason;

  bool get isFinal => status != AirtimeTopupStatus.processing;

  factory AirtimeTopup.fromJson(Map<String, dynamic> json) {
    return AirtimeTopup(
      topupId: '${json['topupId'] ?? ''}',
      status: airtimeStatusFrom('${json['status'] ?? ''}'),
      amount: _toDouble(json['amount']),
      currency: '${json['currency'] ?? 'USD'}',
      operatorName: '${json['operatorName'] ?? ''}',
      phone: '${json['phone'] ?? ''}',
      estimatedDelivered: _toDouble(json['estimatedDelivered']),
      delivered: _toDouble(json['delivered']),
      deliveredCurrency: '${json['deliveredCurrency'] ?? 'HTG'}',
      gatewayId: '${json['gatewayId'] ?? ''}',
      refunded: json['refunded'] == true,
      failureReason: '${json['failureReason'] ?? ''}',
    );
  }
}

/// Eta sèvis Minit Haiti: aktive? similasyon? kont Reloadly gen kòb?
class AirtimeServiceStatus {
  const AirtimeServiceStatus({
    required this.mode,
    required this.enabled,
    required this.reachesReloadly,
    this.funded = true,
    this.balance = 0,
    this.currency = 'USD',
    this.warning = '',
  });

  final String mode;
  final bool enabled;
  final bool reachesReloadly;
  final bool funded;
  final double balance;
  final String currency;
  final String warning;

  bool get canSend => enabled && reachesReloadly && funded;

  factory AirtimeServiceStatus.fromJson(Map<String, dynamic> json) {
    final account = (json['account'] as Map?)?.cast<String, dynamic>();

    return AirtimeServiceStatus(
      mode: '${json['mode'] ?? 'live'}',
      enabled: json['enabled'] != false,
      reachesReloadly: json['reachesReloadly'] != false,
      funded: json['funded'] != false,
      balance: _toDouble(account?['balance']),
      currency: '${account?['currency'] ?? 'USD'}',
      warning: '${json['warning'] ?? ''}',
    );
  }
}
