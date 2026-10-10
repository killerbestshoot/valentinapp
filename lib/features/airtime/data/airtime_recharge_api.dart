import '../../../core/network/api_client.dart';

double _d(dynamic v) => v is num ? v.toDouble() : 0;
DateTime? _date(dynamic v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

class AirtimeRechargeRequest {
  const AirtimeRechargeRequest({
    required this.requestId,
    required this.agentUid,
    required this.agentName,
    required this.amount,
    required this.currency,
    required this.status,
    this.note = '',
    this.createdAt,
    this.decidedAt,
  });

  final String requestId;
  final String agentUid;
  final String agentName;
  final double amount;
  final String currency;
  final String status;
  final String note;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == 'pending';

  factory AirtimeRechargeRequest.fromJson(Map<String, dynamic> j) =>
      AirtimeRechargeRequest(
        requestId: '${j['requestId'] ?? ''}',
        agentUid: '${j['agentUid'] ?? ''}',
        agentName: '${j['agentName'] ?? ''}',
        amount: _d(j['amount']),
        currency: '${j['currency'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        note: '${j['note'] ?? ''}',
        createdAt: _date(j['createdAt']),
        decidedAt: _date(j['decidedAt']),
      );
}

class AirtimeRechargeApi {
  AirtimeRechargeApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static AirtimeRechargeApi? _instance;
  static AirtimeRechargeApi get instance => _instance ??= AirtimeRechargeApi();
  static void override(AirtimeRechargeApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<AirtimeRechargeRequest>> list({String? status}) async {
    final json = await _client.get('/api/airtime/recharge', query: {
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return ((json['recharges'] as List?) ?? const [])
        .map((e) => AirtimeRechargeRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AirtimeRechargeRequest> request({
    required double amount,
    String note = '',
  }) async {
    final json = await _client.post('/api/airtime/recharge', {
      'amount': amount,
      if (note.isNotEmpty) 'note': note,
    });
    return AirtimeRechargeRequest.fromJson(
        json['recharge'] as Map<String, dynamic>);
  }

  Future<AirtimeRechargeRequest> approve(String requestId) async {
    final json =
        await _client.post('/api/airtime/recharge/$requestId/approve');
    return AirtimeRechargeRequest.fromJson(
        json['recharge'] as Map<String, dynamic>);
  }

  Future<void> reject(String requestId) async {
    await _client.post('/api/airtime/recharge/$requestId/reject');
  }
}
