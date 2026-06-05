import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class TransactionService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> getTransactions() {
    return _db
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<void> addTransaction({
    required String client,
    required String phone,
    required String country,
    required String service,
    required double amount,
  }) async {
    final id = AppIds.transaction(
      seed: '$client:$phone:$service:${DateTime.now().toIso8601String()}',
    );

    await _db.collection('transactions').doc(id).set({
      'txId': id,
      'transactionId': id,
      'client': client,
      'phone': phone,
      'country': country,
      'service': service,
      'amount': amount,
      'status': 'pending',
      'date': Timestamp.now(),
    });
  }
}
