import 'package:cloud_firestore/cloud_firestore.dart';

class ExchangeRateService {
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static Future<double> getRateToHTG(String currency) async {
    final c = currency.toUpperCase().trim();
    if (c == 'HTG') return 1;

    final doc = await FirebaseFirestore.instance
        .collection('exchange_rates')
        .doc(c)
        .get();

    final rate = _toDouble(doc.data()?['rateToHTG']);
    if (rate <= 0) {
      throw Exception('Pa gen exchange rate pou $c -> HTG');
    }

    return rate;
  }

  static Future<double> convertToHTG({
    required double amount,
    required String currency,
  }) async {
    final rate = await getRateToHTG(currency);
    return amount * rate;
  }
}
