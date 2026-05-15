import 'package:cloud_firestore/cloud_firestore.dart';

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
    await _transactions.add({
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
