import 'package:mon_premye_app/core/network/api_client.dart';

import '../domain/payment_gateway.dart';
import '../domain/payment_models.dart';

/// Pasrèl ki pale ak serveur VOUPVAPCASH la (`/api/bazik/...`).
///
/// Li pase pa `ApiClient`, ki pote jeton sesyon an. Anvan, klas sa a te voye
/// yon header `x-dev-uid` ak okenn jeton — depi wout Bazik yo sekirize, tout
/// peman t ap resevwa yon 401 an silans.
class HttpPaymentGateway implements PaymentGateway {
  HttpPaymentGateway({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Tradui yon `ApiException` an `PaymentException`, san pèdi kòd la —
  /// se kòd la ki bay bon mesaj la nan `PaymentErrorView`.
  Never _rethrow(ApiException err) {
    throw PaymentException(err.code, err.message);
  }

  Future<Map<String, dynamic>> _post(String path, [Map<String, dynamic>? body]) async {
    try {
      return await _client.post(path, body);
    } on ApiException catch (err) {
      _rethrow(err);
    }
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      return await _client.get(path);
    } on ApiException catch (err) {
      _rethrow(err);
    }
  }

  @override
  Future<TransferQuote> quote({
    required double amount,
    required PaymentNetwork network,
    String? currency,
  }) async {
    final json = await _post('/api/bazik/quote', {
      'amount': amount,
      'network': network.id,
      if (currency != null) 'currency': currency,
    });

    return TransferQuote.fromJson(json['quote'] as Map<String, dynamic>);
  }

  @override
  Future<Transfer> send({
    required double amount,
    required PaymentNetwork network,
    required String phone,
    String receiverName = '',
    String note = '',
    String txId = '',
    String kind = 'payout',
    String? currency,
    String? idempotencySeed,
  }) async {
    final json = await _post('/api/bazik/transfers', {
      'amount': amount,
      'network': network.id,
      'phone': phone,
      'kind': kind,
      if (receiverName.isNotEmpty) 'receiverName': receiverName,
      if (note.isNotEmpty) 'note': note,
      if (txId.isNotEmpty) 'txId': txId,
      if (currency != null) 'currency': currency,
      if (idempotencySeed != null) 'idempotencySeed': idempotencySeed,
    });

    return Transfer.fromJson(json['transfer'] as Map<String, dynamic>);
  }

  @override
  Future<Transfer> refresh(String transferId) async {
    final json = await _post('/api/bazik/transfers/$transferId/refresh');
    return Transfer.fromJson(json['transfer'] as Map<String, dynamic>);
  }

  @override
  Future<GatewayStatus> status() async {
    return GatewayStatus.fromJson(await _get('/api/bazik/status'));
  }

  @override
  Future<WalletBalance> wallet() async {
    final json = await _get('/api/bazik/wallet');
    final wallet = json['wallet'];

    if (wallet == null) {
      return const WalletBalance(balance: 0, currency: 'USD');
    }

    return WalletBalance.fromJson(wallet as Map<String, dynamic>);
  }
}
