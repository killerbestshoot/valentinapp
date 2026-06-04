import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/persistence/firebase_persistence.dart';
import '../domain/transaction_repository.dart';
import '../models/transaction_model.dart';

class FirestoreTransactionRepository implements TransactionRepository {
  FirestoreTransactionRepository._();
  static final FirestoreTransactionRepository instance = FirestoreTransactionRepository._();

  final FirebaseFirestore _firestore = FirebasePersistence.instance.firestore;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('transactions');

  @override
  Future<void> createTransaction({
    required String clientName,
    required String phone,
    required double amount,
    required String country,
    required String service,
  }) async {
    final currentUser = FirebasePersistence.instance.auth.currentUser;
    if (currentUser == null) {
      throw Exception('User must be logged in to create a transaction.');
    }

    await _transactions.add({
      'clientName': clientName.trim(),
      'phone': phone.trim(),
      'amount': amount,
      'country': country.trim(),
      'service': service.trim(),
      'agentId': currentUser.uid,
      'status': 'created',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<List<TransactionModel>> watchTransactions() {
    final currentUser = FirebasePersistence.instance.auth.currentUser;
    if (currentUser == null) {
      return const Stream.empty();
    }

    return _transactions
        .where('agentId', isEqualTo: currentUser.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(TransactionModel.fromSnapshot)
            .toList());
  }
}
