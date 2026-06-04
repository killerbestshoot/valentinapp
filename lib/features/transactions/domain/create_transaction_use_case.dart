import '../data/firestore_transaction_repository.dart';
import '../domain/transaction_repository.dart';

class CreateTransactionUseCase {
  CreateTransactionUseCase({TransactionRepository? repository})
      : _repository = repository ?? FirestoreTransactionRepository.instance;

  final TransactionRepository _repository;

  Future<void> execute({
    required String clientName,
    required String phone,
    required double amount,
    required String country,
    required String service,
  }) {
    return _repository.createTransaction(
      clientName: clientName,
      phone: phone,
      amount: amount,
      country: country,
      service: service,
    );
  }
}
