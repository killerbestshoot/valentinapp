/// Modèl domèn pou peman yo (Bazik: MonCash / NatCash).
///
/// Okenn klas isit la pa konnen ni HTTP, ni Bazik, ni Firebase. Se sa ki fè
/// nou ka chanje pasrèl la san touche UI a.
library;

enum PaymentNetwork { moncash, natcash }

extension PaymentNetworkX on PaymentNetwork {
  String get id => this == PaymentNetwork.natcash ? 'natcash' : 'moncash';

  String get label => this == PaymentNetwork.natcash ? 'NatCash' : 'MonCash';

  /// Minimòm Bazik la aksepte, an HTG (gade bazik/docs/contract.md).
  double get minimumHtg => this == PaymentNetwork.natcash ? 3998 : 100;

  /// NatCash mande non konplè benefisyè a, MonCash non.
  bool get requiresReceiverName => this == PaymentNetwork.natcash;

  static PaymentNetwork fromId(String value) {
    return value.toLowerCase().trim() == 'natcash'
        ? PaymentNetwork.natcash
        : PaymentNetwork.moncash;
  }

  /// Ki rezo yon sèvis nan katalòg la sèvi — `null` si li pa pase sou Bazik.
  ///
  /// Western Union, CAM Transf ak Minit livre yon lòt jan (fizikman oswa sou
  /// yon lòt kanal). Nou pa ka voye yo sou Bazik, donk yo rete an `pending`
  /// jiskaske yon moun konfime livrezon an.
  static PaymentNetwork? forServiceName(String serviceName) {
    final name = serviceName.toLowerCase().trim();
    if (name.contains('natcash')) return PaymentNetwork.natcash;
    if (name.contains('moncash')) return PaymentNetwork.moncash;
    return null;
  }
}

/// Estati yon transfè, jan domèn nou an wè l.
enum TransferStatus { pending, processing, completed, failed, canceled }

TransferStatus transferStatusFrom(String value) {
  switch (value.toLowerCase().trim()) {
    case 'completed':
      return TransferStatus.completed;
    case 'failed':
      return TransferStatus.failed;
    case 'canceled':
    case 'cancelled':
      return TransferStatus.canceled;
    case 'processing':
      return TransferStatus.processing;
    default:
      return TransferStatus.pending;
  }
}

/// Sa yon transfè ap koute, anvan ajan an konfime.
class TransferQuote {
  const TransferQuote({
    required this.network,
    required this.currency,
    required this.amountHtg,
    required this.feeHtg,
    required this.totalHtg,
    required this.feePercent,
    required this.debit,
    required this.rateToHtg,
    String? walletCurrency,
    this.ratesStale = false,
    this.mode = 'live',
  }) : walletCurrency = walletCurrency ?? currency;

  final PaymentNetwork network;

  /// Deviz MONTAN AN (sa kliyan an peye).
  final String currency;

  /// Deviz wallet ajan an: se ladan `debit` la kalkile.
  final String walletCurrency;

  /// To jounen an pa ajou (API a pa reponn depi plis pase 36 h).
  final bool ratesStale;

  /// Sa benefisyè a resevwa.
  final double amountHtg;

  /// Frè Bazik (5% nan sa nou obsève).
  final double feeHtg;

  /// amountHtg + feeHtg.
  final double totalHtg;
  final double feePercent;

  /// Sa nou retire nan wallet ajan an, nan `walletCurrency`.
  final double debit;
  final double rateToHtg;

  /// 'fake' | 'sandbox' | 'live'. Sèvi pou avèti ajan an.
  final String mode;

  factory TransferQuote.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic value) =>
        value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

    return TransferQuote(
      network: PaymentNetworkX.fromId('${json['network']}'),
      currency: '${json['currency'] ?? 'USD'}',
      amountHtg: toDouble(json['amountHtg']),
      feeHtg: toDouble(json['feeHtg']),
      totalHtg: toDouble(json['totalHtg']),
      feePercent: toDouble(json['feePercent']),
      debit: toDouble(json['debit']),
      rateToHtg: toDouble(json['rateToHtg']),
      walletCurrency: json['walletCurrency'] == null ? null : '${json['walletCurrency']}',
      ratesStale: json['ratesStale'] == true,
      mode: '${json['mode'] ?? 'live'}',
    );
  }
}

/// Yon transfè ki soti.
class Transfer {
  const Transfer({
    required this.transferId,
    required this.reference,
    required this.status,
    required this.network,
    required this.amountHtg,
    required this.feeHtg,
    required this.debit,
    required this.currency,
    this.phone = '',
    this.receiverName = '',
    this.failureReason = '',
    this.refunded = false,
    this.gatewayId = '',
  });

  final String transferId;
  final String reference;
  final TransferStatus status;
  final PaymentNetwork network;
  final double amountHtg;
  final double feeHtg;
  final double debit;
  final String currency;
  final String phone;
  final String receiverName;
  final String failureReason;
  final bool refunded;

  /// ID Bazik la. Se li ou chèche sou dashboard Bazik pou jwenn transfè a.
  /// Vid = transfè a pa janm rive sou Bazik.
  final String gatewayId;

  bool get isFinal =>
      status == TransferStatus.completed ||
      status == TransferStatus.failed ||
      status == TransferStatus.canceled;

  factory Transfer.fromJson(Map<String, dynamic> json) {
    double minorToDouble(dynamic value) =>
        (value is num ? value.toDouble() : 0) / 100;

    return Transfer(
      transferId: '${json['transferId'] ?? ''}',
      reference: '${json['reference'] ?? ''}',
      status: transferStatusFrom('${json['status']}'),
      network: PaymentNetworkX.fromId('${json['network']}'),
      amountHtg: minorToDouble(json['amountHtgMinor']),
      feeHtg: minorToDouble(json['feeHtgMinor']),
      debit: minorToDouble(json['debitMinor']),
      currency: '${json['currency'] ?? 'USD'}',
      phone: '${json['phone'] ?? ''}',
      receiverName: '${json['receiverName'] ?? ''}',
      failureReason: '${json['failureReason'] ?? ''}',
      refunded: json['refunded'] == true,
      gatewayId: '${json['gatewayId'] ?? ''}',
    );
  }
}

/// Sld yon wallet ajan.
class WalletBalance {
  const WalletBalance({required this.balance, required this.currency});

  final double balance;
  final String currency;

  factory WalletBalance.fromJson(Map<String, dynamic> json) {
    final value = json['balance'];
    return WalletBalance(
      balance: value is num ? value.toDouble() : 0,
      currency: '${json['currency'] ?? 'USD'}',
    );
  }
}

/// Erè ki gen yon kòd nou ka trete (pa yon senp mesaj).
class PaymentException implements Exception {
  const PaymentException(this.code, this.message);

  final String code;
  final String message;

  /// Èske se yon erè ajan an ka korije li menm?
  bool get isUserFixable => const {
        'amount_too_low',
        'amount_too_high',
        'insufficient_funds',
        'missing_receiver_name',
        'invalid_wallet',
        'invalid_amount',
        // Minit Haiti
        'invalid_phone',
        'operator_not_found',
        'operator_not_supported',
        'operator_mismatch',
        'amount_not_offered',
        'currency_mismatch',
      }.contains(code);

  @override
  String toString() => message;
}

/// Eta pasrèl la: se sa ki esplike "poukisa mwen pa wè anyen sou Bazik".
class GatewayStatus {
  const GatewayStatus({
    required this.mode,
    required this.reachesBazik,
    this.gatewayFunded = true,
    this.available = 0,
    this.currency = 'HTG',
    this.warning = '',
  });

  /// 'fake' | 'sandbox' | 'live'
  final String mode;

  /// `false` lè nou an similasyon: okenn apèl pa rive sou Bazik.
  final bool reachesBazik;

  /// `false` lè float Bazik la vid: chak transfè ap refize.
  final bool gatewayFunded;

  final double available;
  final String currency;
  final String warning;

  /// Èske yon transfè ka reyèlman rive jiska Bazik kounye a?
  bool get canSend => reachesBazik && gatewayFunded;

  bool get isLive => mode == 'live';

  factory GatewayStatus.fromJson(Map<String, dynamic> json) {
    final wallet = json['gatewayWallet'] as Map<String, dynamic>?;
    final available = wallet?['available'];

    return GatewayStatus(
      mode: '${json['mode'] ?? 'live'}',
      reachesBazik: json['reachesBazik'] != false,
      gatewayFunded: json['gatewayFunded'] != false,
      available: available is num ? available.toDouble() : 0,
      currency: '${wallet?['currency'] ?? 'HTG'}',
      warning: '${json['warning'] ?? ''}',
    );
  }
}
