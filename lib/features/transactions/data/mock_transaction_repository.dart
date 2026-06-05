import 'dart:async';

import '../domain/transaction_repository.dart';
import '../models/transaction_model.dart';

class MockTransactionRepository implements TransactionRepository {
  MockTransactionRepository._();
  static final MockTransactionRepository instance =
      MockTransactionRepository._();

  final List<TransactionModel> _transactions = <TransactionModel>[];
  final StreamController<List<TransactionModel>> _transactionsController =
      StreamController<List<TransactionModel>>.broadcast();

  @override
  Future<void> createTransaction({
    required String clientName,
    required String phone,
    required double amount,
    required String country,
    required String service,
  }) async {
    _transactions.insert(
      0,
      TransactionModel(
        id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
        clientName: clientName.trim(),
        phone: phone.trim(),
        amount: amount,
        country: country.trim(),
        service: service.trim(),
        status: 'created',
        createdAt: DateTime.now(),
      ),
    );
    _transactionsController
        .add(List<TransactionModel>.unmodifiable(_transactions));
  }

  @override
  Stream<List<TransactionModel>> watchTransactions() async* {
    yield List<TransactionModel>.unmodifiable(_transactions);
    yield* _transactionsController.stream;
  }
}
