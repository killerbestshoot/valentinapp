import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/payments/domain/payment_models.dart';

import '../domain/airtime_gateway.dart';
import '../domain/airtime_models.dart';

/// Minit Haiti atravè serveur VOUPVAPCASH la (`/api/airtime/...`).
class HttpAirtimeGateway implements AirtimeGateway {
  HttpAirtimeGateway({ApiClient? client})
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  /// Menm tradiksyon ak `HttpPaymentGateway`: kòd la konsève.
  Future<Map<String, dynamic>> _call(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on ApiException catch (err) {
      throw PaymentException(err.code, err.message);
    }
  }

  @override
  Future<AirtimeServiceStatus> status() async {
    return AirtimeServiceStatus.fromJson(
      await _call(() => _client.get('/api/airtime/status')),
    );
  }

  @override
  Future<AirtimeQuote> quote({
    required String phone,
    required double amount,
    String? currency,
    int? operatorId,
  }) async {
    final json = await _call(() => _client.post('/api/airtime/quote', {
          'phone': phone,
          'amount': amount,
          if (currency != null) 'currency': currency,
          if (operatorId != null) 'operatorId': operatorId,
        }));

    return AirtimeQuote.fromJson(json['quote'] as Map<String, dynamic>);
  }

  @override
  Future<AirtimeTopup> deliver({required String txId, int? operatorId}) async {
    final json = await _call(() => _client.post('/api/airtime/topups', {
          'txId': txId,
          if (operatorId != null) 'operatorId': operatorId,
        }));

    return AirtimeTopup.fromJson(json['topup'] as Map<String, dynamic>);
  }

  @override
  Future<AirtimeTopup> refresh(String topupId) async {
    final json = await _call(
      () => _client.post('/api/airtime/topups/$topupId/refresh'),
    );
    return AirtimeTopup.fromJson(json['topup'] as Map<String, dynamic>);
  }
}
