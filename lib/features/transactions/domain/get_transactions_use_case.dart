import '../data/transaction_repository_provider.dart';
import '../domain/transaction_repository.dart';
import '../models/transaction_model.dart';

class GetTransactionsUseCase {
  GetTransactionsUseCase({TransactionRepository? repository})
      : _repository = repository ?? TransactionRepositoryProvider.instance;

  final TransactionRepository _repository;

  Stream<List<TransactionModel>> execute() => _repository.watchTransactions();
}
