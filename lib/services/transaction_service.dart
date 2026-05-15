import 'package:cloud_firestore/cloud_firestore.dart';

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
    await _db.collection('transactions').add({
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
