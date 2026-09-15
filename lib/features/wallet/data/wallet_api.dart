import '../../../core/network/api_client.dart';

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
  final DateTime? createdAt;

  bool get isPending => !processed && status == 'pending';

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
  /// validasyon; se serveur a ki fè konvèsyon ki konte a.
  Future<Map<String, double>> rates() async {
    final json = await _client.get('/api/wallets/rates');
    final raw = (json['rates'] as Map?) ?? const {};

    final rates = <String, double>{};
    raw.forEach((key, value) {
      if (value is num) rates['$key'] = value.toDouble();
    });

    return rates;
  }

  Future<WalletSummary> mine() async {
    final json = await _client.get('/api/wallets/me');
    return WalletSummary.fromJson(json['wallet'] as Map<String, dynamic>);
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
  /// `autoApprove: true` = owner/admin mete kòb la dirèkteman, san de etap.
  /// Li pase pa menm chemen an: rejis la ekri menm jan an.
  Future<String> requestTopup({
    required String targetUid,
    required double amount,
    String currency = 'USD',
    String note = '',
    bool autoApprove = false,
  }) async {
    final json = await _client.post('/api/wallets/topups', {
      'targetUid': targetUid,
      'amount': amount,
      'currency': currency,
      if (note.isNotEmpty) 'note': note,
      if (autoApprove) 'autoApprove': true,
    });

    return '${json['requestId'] ?? ''}';
  }

  /// Kredite wallet la. Serveur a pwoteje kont doub kredi.
  Future<void> approveTopup(String requestId) async {
    await _client.post('/api/wallets/topups/$requestId/approve');
  }

  Future<void> rejectTopup(String requestId, {String note = ''}) async {
    await _client.post('/api/wallets/topups/$requestId/reject', {'note': note});
  }
}
