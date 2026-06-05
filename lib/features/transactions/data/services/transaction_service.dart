import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class TransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');

  Future<void> addTransaction({
    required String clientName,
    required String phone,
    required double amount,
    required String country,
    required String service,
  }) async {
    final txId = AppIds.transaction(
      seed: '$clientName:$phone:$service:${DateTime.now().toIso8601String()}',
    );

    await _transactions.doc(txId).set({
      'txId': txId,
      'transactionId': txId,
      'clientName': clientName,
      'phone': phone,
      'amount': amount,
      'country': country,
      'service': service,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTransactions() {
    return _transactions.orderBy('createdAt', descending: true).snapshots();
  }
}
