import '../data/firestore_transaction_repository.dart';
import '../domain/transaction_repository.dart';
import '../models/transaction_model.dart';

class GetTransactionsUseCase {
  GetTransactionsUseCase({TransactionRepository? repository})
      : _repository = repository ?? FirestoreTransactionRepository.instance;

  final TransactionRepository _repository;

  Stream<List<TransactionModel>> execute() => _repository.watchTransactions();
}
