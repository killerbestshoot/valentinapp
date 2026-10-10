import '../../../core/network/api_client.dart';

double _d(dynamic v) => v is num ? v.toDouble() : 0;

/// Yon transfè Bazik ki bloke (pa fini depi plis pase 15 minit).
class StuckTransfer {
  const StuckTransfer({
    required this.transferId,
    required this.network,
    required this.manualReview,
    required this.amountHtg,
    required this.amount,
    required this.currency,
    required this.debit,
    required this.walletCurrency,
    required this.phone,
    required this.receiverName,
    required this.staffName,
    this.gatewayId,
    this.txStatus,
    this.createdAt,
  });

  final String transferId;
  final String network;

  /// Pa gen ID Bazik e Bazik pa jwenn li: sèlman owner a ka deside.
  final bool manualReview;
  final double amountHtg;
  final double amount;
  final String currency;

  /// Sa ki te soti nan wallet ajan an (montan + frè), nan deviz wallet la.
  final double debit;
  final String walletCurrency;
  final String phone;
  final String receiverName;
  final String staffName;
  final String? gatewayId;
  final String? txStatus;
  final DateTime? createdAt;

  factory StuckTransfer.fromJson(Map<String, dynamic> j) => StuckTransfer(
        transferId: '${j['transferId'] ?? ''}',
        network: '${j['network'] ?? ''}',
        manualReview: j['manualReview'] == true,
        amountHtg: _d(j['amountHtg']),
        amount: _d(j['amount']),
        currency: '${j['currency'] ?? ''}',
        debit: _d(j['debit']),
        walletCurrency: '${j['walletCurrency'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        receiverName: '${j['receiverName'] ?? ''}',
        staffName: '${j['staffName'] ?? ''}',
        gatewayId: j['gatewayId'] as String?,
        txStatus: j['txStatus'] as String?,
        createdAt: j['createdAt'] is num
            ? DateTime.fromMillisecondsSinceEpoch((j['createdAt'] as num).toInt())
            : null,
      );
}

class ReconciliationApi {
  ReconciliationApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static ReconciliationApi? _instance;
  static ReconciliationApi get instance => _instance ??= ReconciliationApi();
  static void override(ReconciliationApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<StuckTransfer>> stuck() async {
    final json = await _client.get('/api/bazik/transfers/review');
    return ((json['transfers'] as List?) ?? const [])
        .map((e) => StuckTransfer.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Lajan an PATI: [gatewayId] se ID transfè a sou dashboard Bazik la.
  Future<void> confirmDelivered(String transferId, {required String gatewayId, required String note}) async {
    await _client.post('/api/bazik/transfers/$transferId/resolve', {
      'action': 'completed',
      'gatewayId': gatewayId,
      'note': note,
    });
  }

  /// Lajan an PA JANM pati: ajan an ranbouse (montan + frè).
  Future<void> markFailed(String transferId, {required String note}) async {
    await _client.post('/api/bazik/transfers/$transferId/resolve', {
      'action': 'failed',
      'note': note,
    });
  }
}
