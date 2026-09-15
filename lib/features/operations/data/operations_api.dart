import '../../../core/network/api_client.dart';

double _d(dynamic v) => v is num ? v.toDouble() : 0;
int _i(dynamic v) => v is num ? v.toInt() : 0;
DateTime? _date(dynamic v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

// ---------------------------------------------------------------------------
// Komisyon
// ---------------------------------------------------------------------------

class CommissionEntry {
  const CommissionEntry({
    required this.txId,
    required this.staffName,
    required this.service,
    required this.txAmount,
    required this.txCurrency,
    required this.agentPct,
    required this.ownerPct,
    required this.agentCommission,
    required this.ownerCommission,
    this.createdAt,
  });

  final String txId;
  final String staffName;
  final String service;
  final double txAmount;
  final String txCurrency;
  final double agentPct;
  final double ownerPct;
  final double agentCommission;
  final double ownerCommission;
  final DateTime? createdAt;

  factory CommissionEntry.fromJson(Map<String, dynamic> j) => CommissionEntry(
        txId: '${j['txId'] ?? ''}',
        staffName: '${j['staffName'] ?? ''}',
        service: '${j['service'] ?? ''}',
        txAmount: _d(j['txAmount']),
        txCurrency: '${j['txCurrency'] ?? ''}',
        agentPct: _d(j['agentPct']),
        ownerPct: _d(j['ownerPct']),
        agentCommission: _d(j['agentCommission']),
        ownerCommission: _d(j['ownerCommission']),
        createdAt: _date(j['createdAt']),
      );
}

class CommissionSummary {
  const CommissionSummary({
    required this.staffName,
    required this.currency,
    required this.count,
    required this.agentTotal,
    required this.ownerTotal,
  });

  final String staffName;
  final String currency;
  final int count;
  final double agentTotal;
  final double ownerTotal;

  factory CommissionSummary.fromJson(Map<String, dynamic> j) => CommissionSummary(
        staffName: '${j['staffName'] ?? ''}',
        currency: '${j['currency'] ?? ''}',
        count: _i(j['count']),
        agentTotal: _d(j['agentTotal']),
        ownerTotal: _d(j['ownerTotal']),
      );
}

class CommissionRunResult {
  const CommissionRunResult({required this.applied, required this.skipped, required this.errors});

  final int applied;
  final int skipped;
  final int errors;
}

class CommissionsApi {
  CommissionsApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static CommissionsApi? _instance;
  static CommissionsApi get instance => _instance ??= CommissionsApi();
  static void override(CommissionsApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<CommissionEntry>> history({int limit = 50}) async {
    final json = await _client.get('/api/commissions', query: {'limit': limit});
    return ((json['commissions'] as List?) ?? const [])
        .map((e) => CommissionEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CommissionSummary>> summary() async {
    final json = await _client.get('/api/commissions/summary');
    return ((json['summary'] as List?) ?? const [])
        .map((e) => CommissionSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Aplike komisyon ki an reta yo. Idempotan: san danje pou rele l plizyè fwa.
  Future<CommissionRunResult> run() async {
    final json = await _client.post('/api/commissions/run');
    return CommissionRunResult(
      applied: _i(json['applied']),
      skipped: _i(json['skipped']),
      errors: _i(json['errors']),
    );
  }
}

// ---------------------------------------------------------------------------
// Sèvis
// ---------------------------------------------------------------------------

class ServiceItem {
  const ServiceItem({
    required this.serviceId,
    required this.name,
    required this.isActive,
    required this.gatewayBacked,
    required this.agentCommissionPct,
    required this.ownerCommissionPct,
  });

  final String serviceId;
  final String name;
  final bool isActive;

  /// `true` = livre pa Bazik (MonCash/NatCash); `false` = livre yon lòt jan.
  final bool gatewayBacked;
  final double agentCommissionPct;
  final double ownerCommissionPct;

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        serviceId: '${j['serviceId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        isActive: j['isActive'] != false,
        gatewayBacked: j['gatewayBacked'] == true,
        agentCommissionPct: _d(j['agentCommissionPct']),
        ownerCommissionPct: _d(j['ownerCommissionPct']),
      );
}

class ServicesApi {
  ServicesApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static ServicesApi? _instance;
  static ServicesApi get instance => _instance ??= ServicesApi();
  static void override(ServicesApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<ServiceItem>> list() async {
    final json = await _client.get('/api/services');
    return ((json['services'] as List?) ?? const [])
        .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceItem> update(
    String serviceId, {
    double? agentCommissionPct,
    double? ownerCommissionPct,
    bool? isActive,
  }) async {
    final json = await _client.patch('/api/services/$serviceId', {
      if (agentCommissionPct != null) 'agentCommissionPct': agentCommissionPct,
      if (ownerCommissionPct != null) 'ownerCommissionPct': ownerCommissionPct,
      if (isActive != null) 'isActive': isActive,
    });
    return ServiceItem.fromJson(json['service'] as Map<String, dynamic>);
  }
}

// ---------------------------------------------------------------------------
// Payout
// ---------------------------------------------------------------------------

class PayoutRequest {
  const PayoutRequest({
    required this.requestId,
    required this.staffName,
    required this.amount,
    required this.currency,
    required this.network,
    required this.phone,
    required this.status,
    this.failureReason = '',
    this.createdAt,
  });

  final String requestId;
  final String staffName;
  final double amount;
  final String currency;
  final String network;
  final String phone;
  final String status;
  final String failureReason;
  final DateTime? createdAt;

  bool get isPending => status == 'pending';

  factory PayoutRequest.fromJson(Map<String, dynamic> j) => PayoutRequest(
        requestId: '${j['requestId'] ?? ''}',
        staffName: '${j['staffName'] ?? ''}',
        amount: _d(j['amount']),
        currency: '${j['currency'] ?? ''}',
        network: '${j['network'] ?? 'moncash'}',
        phone: '${j['phone'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        failureReason: '${j['failureReason'] ?? ''}',
        createdAt: _date(j['createdAt']),
      );
}

class PayoutsApi {
  PayoutsApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static PayoutsApi? _instance;
  static PayoutsApi get instance => _instance ??= PayoutsApi();
  static void override(PayoutsApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<PayoutRequest>> list({String? status}) async {
    final json = await _client.get('/api/payouts', query: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return ((json['payouts'] as List?) ?? const [])
        .map((e) => PayoutRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Mande yon payout. Wallet la PA debite: se apwobasyon an ki voye lajan an.
  Future<PayoutRequest> request({
    required double amount,
    required String phone,
    String network = 'moncash',
    String receiverName = '',
    String note = '',
  }) async {
    final json = await _client.post('/api/payouts', {
      'amount': amount,
      'phone': phone,
      'network': network,
      if (receiverName.isNotEmpty) 'receiverName': receiverName,
      if (note.isNotEmpty) 'note': note,
    });
    return PayoutRequest.fromJson(json['payout'] as Map<String, dynamic>);
  }

  Future<PayoutRequest> approve(String requestId) async {
    final json = await _client.post('/api/payouts/$requestId/approve');
    return PayoutRequest.fromJson(json['payout'] as Map<String, dynamic>);
  }

  Future<void> reject(String requestId, {String note = ''}) async {
    await _client.post('/api/payouts/$requestId/reject', {'note': note});
  }
}

// ---------------------------------------------------------------------------
// Sistèm
// ---------------------------------------------------------------------------

class AppNotification {
  const AppNotification({
    required this.type,
    required this.severity,
    required this.title,
    required this.count,
  });

  final String type;
  final String severity;
  final String title;
  final int count;

  bool get isWarning => severity == 'warning';

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        type: '${j['type'] ?? ''}',
        severity: '${j['severity'] ?? 'info'}',
        title: '${j['title'] ?? ''}',
        count: _i(j['count']),
      );
}

class SystemHealth {
  const SystemHealth({required this.healthy, required this.checks});

  final bool healthy;
  final Map<String, dynamic> checks;

  Map<String, dynamic> get database => (checks['database'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get gateway => (checks['gateway'] as Map?)?.cast<String, dynamic>() ?? {};
  Map<String, dynamic> get data => (checks['data'] as Map?)?.cast<String, dynamic>() ?? {};
}

class SystemApi {
  SystemApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static SystemApi? _instance;
  static SystemApi get instance => _instance ??= SystemApi();
  static void override(SystemApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<AppNotification>> notifications() async {
    final json = await _client.get('/api/system/notifications');
    return ((json['notifications'] as List?) ?? const [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SystemHealth> health() async {
    final json = await _client.get('/api/system/health');
    return SystemHealth(
      healthy: json['healthy'] == true,
      checks: (json['checks'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}
