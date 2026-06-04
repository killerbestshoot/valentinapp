import '../models/transaction_model.dart';

abstract class TransactionRepository {
  Future<void> createTransaction({
    required String clientName,
    required String phone,
    required double amount,
    required String country,
    required String service,
  });

  Stream<List<TransactionModel>> watchTransactions();
}
