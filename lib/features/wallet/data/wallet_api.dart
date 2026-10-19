import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_client.dart';

/// To echanj yo vè HTG (majin owner an deja soustrè), ak dat yo.
class ExchangeRatesSnapshot {
  const ExchangeRatesSnapshot({
    required this.rates,
    this.updatedAt,
    this.stale = false,
  });

  /// `currency` -> konbyen HTG pou 1 inite.
  final Map<String, double> rates;
  final DateTime? updatedAt;

  /// To yo pa soti nan API a, oswa yo depase 24 è.
  final bool stale;

  /// Konbyen `to` pou 1 `from`, atravè HTG. `null` si youn manke.
  double? cross(String from, String to) {
    final a = from == 'HTG' ? 1.0 : rates[from];
    final b = to == 'HTG' ? 1.0 : rates[to];
    if (a == null || b == null || b == 0) return null;
    return a / b;
  }
}

class WalletSummary {
  const WalletSummary({
    required this.uid,
    required this.balance,
    required this.currency,
    this.enterpriseName = '',
    this.role = '',
  });

  final String uid;
  final double balance;
  final String currency;
  final String enterpriseName;
  final String role;

  String get label => '${balance.toStringAsFixed(2)} $currency';

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      uid: '${json['uid'] ?? ''}',
      balance: json['balance'] is num ? (json['balance'] as num).toDouble() : 0,
      currency: '${json['currency'] ?? 'USD'}',
      enterpriseName: '${json['enterpriseName'] ?? ''}',
      role: '${json['role'] ?? ''}',
    );
  }
}

/// Foto prèv yon virement (JPEG/PNG/WebP, 700 Ko maksimòm sou sèvè a).
class TopupProof {
  const TopupProof({required this.mime, required this.bytes});

  final String mime;
  final Uint8List bytes;
}

/// Yon kont bank antrepriz la — kote ajan yo vire pou yon rechaj.
class BankAccount {
  const BankAccount({
    this.id = '',
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.currency = 'HTG',
    this.instructions = '',
  });

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String currency;
  final String instructions;

  factory BankAccount.fromJson(Map<String, dynamic> json) => BankAccount(
        id: '${json['id'] ?? ''}',
        bankName: '${json['bankName'] ?? ''}',
        accountName: '${json['accountName'] ?? ''}',
        accountNumber: '${json['accountNumber'] ?? ''}',
        currency: '${json['currency'] ?? 'HTG'}',
        instructions: '${json['instructions'] ?? ''}',
      );

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) 'id': id,
        'bankName': bankName,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'currency': currency,
        'instructions': instructions,
      };
}

class PslFallbackSettings {
  const PslFallbackSettings({required this.configured, required this.enabled});

  final bool configured;
  final bool enabled;
}

/// Yon mouvman nan rejis la.
class LedgerEntry {
  const LedgerEntry({
    required this.ledgerId,
    required this.type,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.balanceBefore,
    required this.balanceAfter,
    this.note = '',
    this.serviceName = '',
    this.createdAt,
  });

  final String ledgerId;
  final String type;
  final String direction;
  final double amount;
  final String currency;
  final double balanceBefore;
  final double balanceAfter;
  final String note;
  final String serviceName;
  final DateTime? createdAt;

  bool get isCredit => direction == 'credit';

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => v is num ? v.toDouble() : 0;
    final created = json['createdAt'];

    return LedgerEntry(
      ledgerId: '${json['ledgerId'] ?? ''}',
      type: '${json['type'] ?? ''}',
      direction: '${json['direction'] ?? 'credit'}',
      amount: toDouble(json['amount']),
      currency: '${json['currency'] ?? 'USD'}',
      balanceBefore: toDouble(json['balanceBefore']),
      balanceAfter: toDouble(json['balanceAfter']),
      note: '${json['note'] ?? ''}',
      serviceName: '${json['serviceName'] ?? ''}',
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
    );
  }
}

/// Yon demann rechaj wallet.
class TopupRequest {
  const TopupRequest({
    required this.requestId,
    required this.status,
    required this.amount,
    required this.currency,
    required this.targetUid,
    required this.targetName,
    this.note = '',
    this.requestedByName = '',
    this.processed = false,
    this.method = 'manual',
    this.bankReference = '',
    this.bankAccount = '',
    this.hasProof = false,
    this.createdAt,
  });

  final String requestId;
  final String status;
  final double amount;
  final String currency;
  final String targetUid;
  final String targetName;
  final String note;
  final String requestedByName;
  final bool processed;

  /// `manual` (kach / admin) oswa `bank` (virement bancaire).
  final String method;
  final String bankReference;
  final String bankAccount;

  /// Ajan an te mete yon foto prèv virement ([WalletApi.topupProof]).
  final bool hasProof;
  final DateTime? createdAt;

  bool get isPending => !processed && status == 'pending';
  bool get isBank => method == 'bank';

  factory TopupRequest.fromJson(Map<String, dynamic> json) {
    final created = json['createdAt'];

    return TopupRequest(
      requestId: '${json['requestId'] ?? ''}',
      status: '${json['status'] ?? 'pending'}',
      amount: json['amount'] is num ? (json['amount'] as num).toDouble() : 0,
      currency: '${json['currency'] ?? 'USD'}',
      targetUid: '${json['targetUid'] ?? ''}',
      targetName: '${json['targetName'] ?? ''}',
      note: '${json['note'] ?? ''}',
      requestedByName: '${json['requestedByName'] ?? ''}',
      processed: json['processed'] == true,
      method: '${json['method'] ?? 'manual'}',
      bankReference: '${json['bankReference'] ?? ''}',
      bankAccount: '${json['bankAccount'] ?? ''}',
      hasProof: json['hasProof'] == true,
      createdAt: created is num
          ? DateTime.fromMillisecondsSinceEpoch(created.toInt())
          : null,
    );
  }
}

/// Wallet ak rechaj — ranplase `balances`, `wallet_ledger`,
/// `wallet_topup_requests`.
class WalletApi {
  WalletApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static WalletApi? _instance;
  static WalletApi get instance => _instance ??= WalletApi();

  static void override(WalletApi api) => _instance = api;
  static void reset() => _instance = null;

  /// To echanj yo (vè HTG). UI a sèvi ak sa pou montre konvèsyon an anvan
  /// validasyon; se serveur a ki fè konvèsyon ki konte a. To ki retounen la
  /// deja gen majin owner an soustrè.
  Future<Map<String, double>> rates() async {
    final json = await _client.get('/api/wallets/rates');
    final raw = (json['rates'] as Map?) ?? const {};

    final rates = <String, double>{};
    raw.forEach((key, value) {
      if (value is num) rates['$key'] = value.toDouble();
    });

    return rates;
  }

  /// To yo + dat mizajou yo, pou kat to echanj ekran prensipal la.
  Future<ExchangeRatesSnapshot> ratesSnapshot() async {
    final json = await _client.get('/api/wallets/rates');
    final raw = (json['rates'] as Map?) ?? const {};
    final meta = (json['meta'] as Map?) ?? const {};

    final rates = <String, double>{};
    raw.forEach((key, value) {
      if (value is num) rates['$key'] = value.toDouble();
    });

    final updatedAt = meta['updatedAt'];
    return ExchangeRatesSnapshot(
      rates: rates,
      updatedAt: updatedAt is num
          ? DateTime.fromMillisecondsSinceEpoch(updatedAt.toInt())
          : null,
      stale: meta['stale'] == true,
    );
  }

  /// Majin owner an sou to echanj yo (an HTG pa inite). Retounen 0 si pa gen.
  Future<double> exchangeMargin() async {
    final json = await _client.get('/api/settings/exchange-margin');
    final value = json['margin'];
    return value is num ? value.toDouble() : 0;
  }

  /// Mete ajou majin owner an. Owner sèlman ka rele sa a.
  Future<double> setExchangeMargin(double margin) async {
    final json = await _client
        .patch('/api/settings/exchange-margin', {'margin': margin});
    final value = json['margin'];
    return value is num ? value.toDouble() : 0;
  }

  /// Kont bank antrepriz la. Tout staff ka li yo.
  Future<List<BankAccount>> bankAccounts() async {
    final json = await _client.get('/api/settings/bank-accounts');
    return ((json['accounts'] as List?) ?? const [])
        .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Ranplase tout lis la. Owner/admin sèlman.
  Future<List<BankAccount>> saveBankAccounts(List<BankAccount> accounts) async {
    final json = await _client.patch('/api/settings/bank-accounts', {
      'accounts': accounts.map((a) => a.toJson()).toList(),
    });
    return ((json['accounts'] as List?) ?? const [])
        .map((e) => BankAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PslFallbackSettings> pslFallbackSettings() async {
    final json = await _client.get('/api/settings/psl-fallback');
    return PslFallbackSettings(
      configured: json['configured'] == true,
      enabled: json['enabled'] == true,
    );
  }

  Future<PslFallbackSettings> setPslFallbackEnabled(bool enabled) async {
    final json = await _client.patch(
      '/api/settings/psl-fallback',
      {'enabled': enabled},
    );
    return PslFallbackSettings(
      configured: json['configured'] == true,
      enabled: json['enabled'] == true,
    );
  }

  Future<WalletSummary> mine() async {
    final json = await _client.get('/api/wallets/me');
    return WalletSummary.fromJson(json['wallet'] as Map<String, dynamic>);
  }

  Future<({WalletSummary main, WalletSummary commission})> mineWithCommission() async {
    final json = await _client.get('/api/wallets/me');
    return (
      main: WalletSummary.fromJson(json['wallet'] as Map<String, dynamic>),
      commission: WalletSummary.fromJson(json['commissionWallet'] as Map<String, dynamic>),
    );
  }

  Future<void> transferCommission({required double amount, required String direction, required String idempotencyKey}) async {
    await _client.post('/api/wallets/transfer-commission', {
      'amount': amount,
      'direction': direction,
      'idempotencyKey': idempotencyKey,
    });
  }

  Future<WalletSummary> of(String uid) async {
    final json = await _client.get('/api/wallets/$uid');
    return WalletSummary.fromJson(json['wallet'] as Map<String, dynamic>);
  }

  Future<List<LedgerEntry>> ledger(String uid, {int limit = 50}) async {
    final json = await _client.get('/api/wallets/$uid/ledger', query: {
      'limit': limit,
    });

    final items = (json['entries'] as List?) ?? const [];
    return items
        .map((item) => LedgerEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<TopupRequest>> topups({String? status}) async {
    final json = await _client.get('/api/wallets/topups', query: {
      if (status != null && status.isNotEmpty) 'status': status,
    });

    final items = (json['topups'] as List?) ?? const [];
    return items
        .map((item) => TopupRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Mande yon rechaj.
  ///
  /// Owner sèlman: mete sòld wallet [uid] sou [balance] egzakteman (nan deviz
  /// wallet la). Diferans lan ekri nan rejis la kòm yon ajisteman ak [note].
  Future<WalletSummary> adjust(String uid, {required double balance, required String note}) async {
    final json = await _client.post('/api/wallets/$uid/adjust', {'balance': balance, 'note': note});
    return WalletSummary.fromJson(json['wallet'] as Map<String, dynamic>);
  }

  /// `autoApprove: true` = owner/admin mete kòb la dirèkteman, san de etap.
  /// Li pase pa menm chemen an: rejis la ekri menm jan an.
  Future<String> requestTopup({
    required String targetUid,
    required double amount,
    String currency = 'USD',
    String note = '',
    bool autoApprove = false,
    String? bankReference,
    String? bankAccountId,
    TopupProof? proof,
  }) async {
    final json = await _client.post('/api/wallets/topups', {
      'targetUid': targetUid,
      'amount': amount,
      'currency': currency,
      if (note.isNotEmpty) 'note': note,
      if (autoApprove) 'autoApprove': true,
      // Virement bancaire: referans lan + kont antrepriz ajan an vire sou li a.
      if (bankReference != null) ...{
        'method': 'bank',
        'bankReference': bankReference,
        if (bankAccountId != null) 'bankAccountId': bankAccountId,
        if (proof != null) 'proof': {'mime': proof.mime, 'data': base64Encode(proof.bytes)},
      },
    });

    return '${json['requestId'] ?? ''}';
  }

  /// Foto prèv virement yon demann rechaj.
  Future<TopupProof> topupProof(String requestId) async {
    final json = await _client.get('/api/wallets/topups/$requestId/proof');
    return TopupProof(mime: '${json['mime'] ?? 'image/jpeg'}', bytes: base64Decode('${json['data'] ?? ''}'));
  }

  /// Kredite wallet la. Serveur a pwoteje kont doub kredi.
  Future<void> approveTopup(String requestId) async {
    await _client.post('/api/wallets/topups/$requestId/approve');
  }

  Future<void> rejectTopup(String requestId, {String note = ''}) async {
    await _client.post('/api/wallets/topups/$requestId/reject', {'note': note});
  }
}
