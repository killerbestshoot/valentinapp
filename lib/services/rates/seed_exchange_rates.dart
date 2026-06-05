import 'package:cloud_firestore/cloud_firestore.dart';

class SeedExchangeRates {
  static Future<void> run() async {
    final db = FirebaseFirestore.instance;

    final rates = {
      'HTG': 1,
      'USD': 132,
      'MXN': 7.25,
      'DOP': 2.25,
      'CLP': 0.14,
      'BRL': 24,
    };

    for (final e in rates.entries) {
      await db.collection('exchange_rates').doc(e.key).set({
        'currency': e.key,
        'rateToHTG': e.value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }
}
