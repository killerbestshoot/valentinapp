import '../../../core/network/api_client.dart';

double _d(dynamic v) => v is num ? v.toDouble() : 0;
int _i(dynamic v) => v is num ? v.toInt() : 0;
List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) f) =>
    ((v as List?) ?? const []).map((e) => f((e as Map).cast<String, dynamic>())).toList();

/// Rezo yon tranzaksyon sou tablo a.
const analyticsNetworks = ['moncash', 'natcash', 'psl', 'minit', 'manual'];

const analyticsNetworkLabels = {
  'moncash': 'MonCash',
  'natcash': 'NatCash',
  'psl': 'PSL',
  'minit': 'Minit Haiti',
  'manual': 'Manyèl',
};

/// Kijan pou gwoupe tablo analiz la.
enum AnalyticsGroupBy {
  agent('agent', 'Ajan'),
  network('network', 'Rezo'),
  currency('currency', 'Deviz'),
  week('week', 'Semèn'),
  status('status', 'Estati');

  const AnalyticsGroupBy(this.wire, this.label);
  final String wire;
  final String label;
}

class AnalyticsKpi {
  const AnalyticsKpi({
    required this.count,
    required this.delivered,
    required this.failed,
    required this.pending,
    required this.volume,
    required this.fee,
    required this.agentCommission,
    required this.ownerNet,
    required this.successRate,
    required this.averageTicket,
  });

  final int count;
  final int delivered;
  final int failed;
  final int pending;
  final double volume;
  final double fee;
  final double agentCommission;
  final double ownerNet;

  /// `null` si pa gen tranzaksyon fini (livre oswa echwe).
  final double? successRate;
  final double averageTicket;

  factory AnalyticsKpi.fromJson(Map<String, dynamic> j) => AnalyticsKpi(
        count: _i(j['count']),
        delivered: _i(j['delivered']),
        failed: _i(j['failed']),
        pending: _i(j['pending']),
        volume: _d(j['volume']),
        fee: _d(j['fee']),
        agentCommission: _d(j['agentCommission']),
        ownerNet: _d(j['ownerNet']),
        successRate: j['successRate'] is num ? _d(j['successRate']) : null,
        averageTicket: _d(j['averageTicket']),
      );
}

class AnalyticsDay {
  const AnalyticsDay({
    required this.date,
    required this.count,
    required this.delivered,
    required this.failed,
    required this.fee,
    required this.ownerNet,
    required this.volume,
  });

  /// YYYY-MM-DD, lè Ayiti.
  final String date;
  final int count;
  final int delivered;
  final int failed;
  final double fee;
  final double ownerNet;

  /// Volim livre pa rezo.
  final Map<String, double> volume;

  double get totalVolume => volume.values.fold(0, (a, b) => a + b);

  factory AnalyticsDay.fromJson(Map<String, dynamic> j) => AnalyticsDay(
        date: '${j['date'] ?? ''}',
        count: _i(j['count']),
        delivered: _i(j['delivered']),
        failed: _i(j['failed']),
        fee: _d(j['fee']),
        ownerNet: _d(j['ownerNet']),
        volume: ((j['volume'] as Map?) ?? const {})
            .map((k, v) => MapEntry('$k', _d(v))),
      );
}

class AnalyticsGroup {
  const AnalyticsGroup({
    required this.key,
    required this.label,
    required this.count,
    required this.delivered,
    required this.volume,
    required this.share,
    required this.averageTicket,
    required this.fee,
    required this.agentCommission,
    required this.ownerNet,
    required this.successRate,
    required this.trend,
  });

  final String key;
  final String label;
  final int count;
  final int delivered;
  final double volume;
  final double share;
  final double averageTicket;
  final double fee;
  final double agentCommission;
  final double ownerNet;
  final double? successRate;
  final List<double> trend;

  factory AnalyticsGroup.fromJson(Map<String, dynamic> j) => AnalyticsGroup(
        key: '${j['key'] ?? ''}',
        label: '${j['label'] ?? ''}',
        count: _i(j['count']),
        delivered: _i(j['delivered']),
        volume: _d(j['volume']),
        share: _d(j['share']),
        averageTicket: _d(j['averageTicket']),
        fee: _d(j['fee']),
        agentCommission: _d(j['agentCommission']),
        ownerNet: _d(j['ownerNet']),
        successRate: j['successRate'] is num ? _d(j['successRate']) : null,
        trend: ((j['trend'] as List?) ?? const []).map(_d).toList(),
      );
}

class AnalyticsNetwork {
  const AnalyticsNetwork({
    required this.network,
    required this.label,
    required this.count,
    required this.volume,
    required this.share,
    required this.successRate,
    required this.medianSeconds,
  });

  final String network;
  final String label;
  final int count;
  final double volume;
  final double share;
  final double? successRate;
  final int? medianSeconds;

  factory AnalyticsNetwork.fromJson(Map<String, dynamic> j) => AnalyticsNetwork(
        network: '${j['network'] ?? ''}',
        label: '${j['label'] ?? ''}',
        count: _i(j['count']),
        volume: _d(j['volume']),
        share: _d(j['share']),
        successRate: j['successRate'] is num ? _d(j['successRate']) : null,
        medianSeconds: j['medianSeconds'] is num ? _i(j['medianSeconds']) : null,
      );
}

class AnalyticsAlert {
  const AnalyticsAlert({required this.level, required this.code, required this.title, required this.detail});

  /// `critical`, `warning` oswa `info`.
  final String level;
  final String code;
  final String title;
  final String detail;

  factory AnalyticsAlert.fromJson(Map<String, dynamic> j) => AnalyticsAlert(
        level: '${j['level'] ?? 'info'}',
        code: '${j['code'] ?? ''}',
        title: '${j['title'] ?? ''}',
        detail: '${j['detail'] ?? ''}',
      );
}

class AnalyticsRecent {
  const AnalyticsRecent({
    required this.txId,
    required this.staffName,
    required this.phone,
    required this.network,
    required this.amount,
    required this.currency,
    required this.status,
    this.createdAt,
  });

  final String txId;
  final String staffName;

  /// Deja maske pa serveur a.
  final String phone;
  final String network;
  final double amount;
  final String currency;

  /// `delivered`, `failed`, `pending` oswa `verifying`.
  final String status;
  final DateTime? createdAt;

  factory AnalyticsRecent.fromJson(Map<String, dynamic> j) => AnalyticsRecent(
        txId: '${j['txId'] ?? ''}',
        staffName: '${j['staffName'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        network: '${j['network'] ?? ''}',
        amount: _d(j['amount']),
        currency: '${j['currency'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        createdAt: j['createdAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch(_i(j['createdAt']))
            : null,
      );
}

class OwnerAnalytics {
  const OwnerAnalytics({
    required this.days,
    required this.currency,
    required this.current,
    required this.previous,
    required this.series,
    required this.groups,
    required this.heatmap,
    required this.networks,
    required this.alerts,
    required this.recent,
    this.generatedAt,
  });

  final int days;
  final String currency;
  final AnalyticsKpi current;
  final AnalyticsKpi previous;
  final List<AnalyticsDay> series;
  final List<AnalyticsGroup> groups;

  /// 7 liy (lendi → dimanch) × 24 lè.
  final List<List<int>> heatmap;
  final List<AnalyticsNetwork> networks;
  final List<AnalyticsAlert> alerts;
  final List<AnalyticsRecent> recent;
  final DateTime? generatedAt;

  factory OwnerAnalytics.fromJson(Map<String, dynamic> j) {
    final kpis = (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {};
    Map<String, dynamic> m(dynamic v) => (v as Map?)?.cast<String, dynamic>() ?? const {};
    return OwnerAnalytics(
      days: _i(j['days']),
      currency: '${j['currency'] ?? 'HTG'}',
      current: AnalyticsKpi.fromJson(m(kpis['current'])),
      previous: AnalyticsKpi.fromJson(m(kpis['previous'])),
      series: _list(j['series'], AnalyticsDay.fromJson),
      groups: _list(j['groups'], AnalyticsGroup.fromJson),
      heatmap: ((j['heatmap'] as List?) ?? const [])
          .map((row) => ((row as List?) ?? const []).map(_i).toList())
          .toList(),
      networks: _list(j['networkStats'], AnalyticsNetwork.fromJson),
      alerts: _list(j['alerts'], AnalyticsAlert.fromJson),
      recent: _list(j['recent'], AnalyticsRecent.fromJson),
      generatedAt: j['generatedAt'] is num
          ? DateTime.fromMillisecondsSinceEpoch(_i(j['generatedAt']))
          : null,
    );
  }
}

/// Tablo ajan an: sèlman tranzaksyon pa l.
class AgentAnalytics {
  const AgentAnalytics({
    required this.days,
    required this.count,
    required this.delivered,
    required this.failed,
    required this.pending,
    required this.volumeHtg,
    required this.fee,
    required this.commissionEarned,
    required this.commissionPending,
    required this.successRate,
    required this.averageTicketHtg,
    required this.currency,
    required this.commissionSeries,
    required this.inProgress,
    this.walletBalance,
    this.walletCurrency,
    this.walletBalanceHtg,
  });

  final int days;
  final int count;
  final int delivered;
  final int failed;
  final int pending;
  final double volumeHtg;

  /// Frè ak komisyon: nan deviz wallet ajan an ([currency]).
  final double fee;
  final double commissionEarned;
  final double commissionPending;
  final double? successRate;
  final double averageTicketHtg;
  final String currency;
  final List<({String date, double earned, double pending, int count})> commissionSeries;
  final List<AgentInProgress> inProgress;
  final double? walletBalance;
  final String? walletCurrency;
  final double? walletBalanceHtg;

  factory AgentAnalytics.fromJson(Map<String, dynamic> j) {
    final k = (j['kpis'] as Map?)?.cast<String, dynamic>() ?? const {};
    final w = (j['wallet'] as Map?)?.cast<String, dynamic>();
    return AgentAnalytics(
      days: _i(j['days']),
      count: _i(k['count']),
      delivered: _i(k['delivered']),
      failed: _i(k['failed']),
      pending: _i(k['pending']),
      volumeHtg: _d(k['volumeHtg']),
      fee: _d(k['fee']),
      commissionEarned: _d(k['commissionEarned']),
      commissionPending: _d(k['commissionPending']),
      successRate: k['successRate'] is num ? _d(k['successRate']) : null,
      averageTicketHtg: _d(k['averageTicketHtg']),
      currency: '${k['currency'] ?? 'HTG'}',
      commissionSeries: ((j['commissionSeries'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .map((e) => (date: '${e['date']}', earned: _d(e['earned']), pending: _d(e['pending']), count: _i(e['count'])))
          .toList(),
      inProgress: _list(j['inProgress'], AgentInProgress.fromJson),
      walletBalance: w == null ? null : _d(w['balance']),
      walletCurrency: w?['currency'] as String?,
      walletBalanceHtg: w == null ? null : _d(w['balanceHtg']),
    );
  }
}

class AgentInProgress {
  const AgentInProgress({
    required this.txId,
    required this.service,
    required this.clientName,
    required this.phone,
    required this.amount,
    required this.currency,
    required this.status,
    required this.manualReview,
    this.createdAt,
  });

  final String txId;
  final String service;
  final String clientName;
  final String phone;
  final double amount;
  final String currency;

  /// `pending` oswa `verifying`.
  final String status;
  final bool manualReview;
  final DateTime? createdAt;

  factory AgentInProgress.fromJson(Map<String, dynamic> j) => AgentInProgress(
        txId: '${j['txId'] ?? ''}',
        service: '${j['service'] ?? ''}',
        clientName: '${j['clientName'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        amount: _d(j['amount']),
        currency: '${j['currency'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        manualReview: j['manualReview'] == true,
        createdAt: j['createdAt'] is num ? DateTime.fromMillisecondsSinceEpoch(_i(j['createdAt'])) : null,
      );
}

class AnalyticsApi {
  AnalyticsApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static AnalyticsApi? _instance;
  static AnalyticsApi get instance => _instance ??= AnalyticsApi();
  static void override(AnalyticsApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<AgentAnalytics> agent({int days = 1}) async {
    final json = await _client.get('/api/analytics/agent', query: {'days': days});
    return AgentAnalytics.fromJson(json);
  }

  Future<OwnerAnalytics> owner({
    int days = 30,
    String currency = 'HTG',
    AnalyticsGroupBy groupBy = AnalyticsGroupBy.agent,
    Set<String>? networks,
  }) async {
    final json = await _client.get('/api/analytics/owner', query: {
      'days': days,
      'currency': currency,
      'groupBy': groupBy.wire,
      if (networks != null && networks.length < analyticsNetworks.length)
        'networks': networks.join(','),
    });
    return OwnerAnalytics.fromJson(json);
  }
}
