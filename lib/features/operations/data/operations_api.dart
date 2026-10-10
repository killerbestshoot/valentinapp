import '../../../core/network/api_client.dart';
import 'package:mon_premye_app/features/airtime/domain/reloadly_overview.dart';

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

  /// Komisyon tout ajan yo an dirèk (owner/admin). `days`: 1, 7 oswa 30.
  Future<LiveCommissions> live({int days = 1, String currency = 'HTG'}) async {
    final json = await _client.get(
      '/api/commissions/live',
      query: {'days': days, 'currency': currency},
    );
    return LiveCommissions.fromJson(json);
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

/// Yon ajan sou ekran komisyon an dirèk la. Montan yo nan [LiveCommissions.currency].
class LiveAgentCommission {
  const LiveAgentCommission({
    required this.staffUid,
    required this.staffName,
    required this.count,
    required this.volume,
    required this.fee,
    required this.agentCommission,
    required this.ownerGross,
    required this.gatewayCost,
    required this.ownerNet,
    required this.pendingCount,
    required this.pendingAgent,
    required this.pendingOwner,
    this.lastAt,
  });

  final String staffUid;
  final String staffName;
  final int count;
  final double volume;
  final double fee;
  final double agentCommission;
  final double ownerGross;
  final double gatewayCost;
  final double ownerNet;
  final int pendingCount;
  final double pendingAgent;
  final double pendingOwner;
  final DateTime? lastAt;

  factory LiveAgentCommission.fromJson(Map<String, dynamic> j) => LiveAgentCommission(
        staffUid: '${j['staffUid'] ?? ''}',
        staffName: '${j['staffName'] ?? ''}',
        count: _i(j['count']),
        volume: _d(j['volume']),
        fee: _d(j['fee']),
        agentCommission: _d(j['agentCommission']),
        ownerGross: _d(j['ownerGross']),
        gatewayCost: _d(j['gatewayCost']),
        ownerNet: _d(j['ownerNet']),
        pendingCount: _i(j['pendingCount']),
        pendingAgent: _d(j['pendingAgent']),
        pendingOwner: _d(j['pendingOwner']),
        lastAt: _date(j['lastAt']),
      );
}

class LiveCommissionLine {
  const LiveCommissionLine({
    required this.txId,
    required this.staffName,
    required this.service,
    required this.currency,
    required this.fee,
    required this.agentCommission,
    required this.ownerNet,
    this.createdAt,
  });

  final String txId;
  final String staffName;
  final String service;
  final String currency;
  final double fee;
  final double agentCommission;
  final double ownerNet;
  final DateTime? createdAt;

  factory LiveCommissionLine.fromJson(Map<String, dynamic> j) => LiveCommissionLine(
        txId: '${j['txId'] ?? ''}',
        staffName: '${j['staffName'] ?? ''}',
        service: '${j['service'] ?? ''}',
        currency: '${j['currency'] ?? ''}',
        fee: _d(j['fee']),
        agentCommission: _d(j['agentCommission']),
        ownerNet: _d(j['ownerNet']),
        createdAt: _date(j['createdAt']),
      );
}

class LiveCommissions {
  const LiveCommissions({
    required this.days,
    required this.currency,
    required this.count,
    required this.fee,
    required this.agentCommission,
    required this.gatewayCost,
    required this.ownerNet,
    required this.pendingAgent,
    required this.pendingOwner,
    required this.agents,
    required this.recent,
    this.serverTime,
  });

  final int days;
  final String currency;
  final int count;
  final double fee;
  final double agentCommission;
  final double gatewayCost;
  final double ownerNet;
  final double pendingAgent;
  final double pendingOwner;
  final List<LiveAgentCommission> agents;
  final List<LiveCommissionLine> recent;
  final DateTime? serverTime;

  factory LiveCommissions.fromJson(Map<String, dynamic> j) {
    final totals = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    return LiveCommissions(
      days: _i(j['days']),
      currency: '${j['currency'] ?? 'HTG'}',
      count: _i(totals['count']),
      fee: _d(totals['fee']),
      agentCommission: _d(totals['agentCommission']),
      gatewayCost: _d(totals['gatewayCost']),
      ownerNet: _d(totals['ownerNet']),
      pendingAgent: _d(totals['pendingAgent']),
      pendingOwner: _d(totals['pendingOwner']),
      agents: ((j['agents'] as List?) ?? const [])
          .map((e) => LiveAgentCommission.fromJson(e as Map<String, dynamic>))
          .toList(),
      recent: ((j['recent'] as List?) ?? const [])
          .map((e) => LiveCommissionLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTime: _date(j['serverTime']),
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
    this.feePct = 0,
    this.feeMinHtg = 0,
    this.agentSharePct = 0,
    this.gatewayCostPct = 0,
    this.ownerMarginPct = 0,
  });

  final String serviceId;
  final String name;
  final bool isActive;

  /// `true` = livre pa Bazik (MonCash/NatCash); `false` = livre yon lòt jan.
  final bool gatewayBacked;
  final double agentCommissionPct;
  final double ownerCommissionPct;

  /// Frè platfòm nan, an % montan an. Owner a fikse l; li obligatwa.
  final double feePct;

  /// Frè minimòm, an HTG.
  final double feeMinHtg;

  /// Pati ajan an NAN FRÈ A (owner a pran rès la).
  final double agentSharePct;

  /// Estimasyon sa pasrèl la (Bazik/PSL) pran, an % montan an.
  final double gatewayCostPct;

  /// Sa owner a kenbe an % montan an. Negatif = pèt sou chak transfè.
  final double ownerMarginPct;

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        serviceId: '${j['serviceId'] ?? ''}',
        name: '${j['name'] ?? ''}',
        isActive: j['isActive'] != false,
        gatewayBacked: j['gatewayBacked'] == true,
        agentCommissionPct: _d(j['agentCommissionPct']),
        ownerCommissionPct: _d(j['ownerCommissionPct']),
        feePct: _d(j['feePct']),
        feeMinHtg: _d(j['feeMinHtg']),
        agentSharePct: _d(j['agentSharePct']),
        gatewayCostPct: _d(j['gatewayCostPct']),
        ownerMarginPct: _d(j['ownerMarginPct']),
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
    double? feePct,
    double? feeMinHtg,
    double? agentSharePct,
    bool? isActive,
  }) async {
    final json = await _client.patch('/api/services/$serviceId', {
      if (agentCommissionPct != null) 'agentCommissionPct': agentCommissionPct,
      if (ownerCommissionPct != null) 'ownerCommissionPct': ownerCommissionPct,
      if (feePct != null) 'feePct': feePct,
      if (feeMinHtg != null) 'feeMinHtg': feeMinHtg,
      if (agentSharePct != null) 'agentSharePct': agentSharePct,
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

  /// Solvabilite: float ajan yo kontre pwovizyon pasrèl yo. Owner sèlman —
  /// pou lòt moun li rive ak `restricted: true`.
  Map<String, dynamic> get solvency =>
      (checks['solvency'] as Map?)?.cast<String, dynamic>() ?? const {'restricted': true};
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

  /// Pèmisyon ak done kont Reloadly la (owner/admin).
  Future<ReloadlyOverview> reloadly() async {
    return ReloadlyOverview.fromJson(await _client.get('/api/system/reloadly'));
  }

  Future<SystemHealth> health() async {
    final json = await _client.get('/api/system/health');
    return SystemHealth(
      healthy: json['healthy'] == true,
      checks: (json['checks'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}
