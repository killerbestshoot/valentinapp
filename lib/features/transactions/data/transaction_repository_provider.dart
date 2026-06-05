import '../../../core/config/app_environment.dart';
import '../domain/transaction_repository.dart';
import 'firestore_transaction_repository.dart';
import 'mock_transaction_repository.dart';

class TransactionRepositoryProvider {
  TransactionRepositoryProvider._();

  static TransactionRepository get instance {
    if (AppEnvironment.mockFirebase) {
      return MockTransactionRepository.instance;
    }
    return FirestoreTransactionRepository.instance;
  }
}
