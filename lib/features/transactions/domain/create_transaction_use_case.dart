import '../../../core/models/app_role.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../../auth/domain/auth_repository.dart';
import '../data/transaction_repository_provider.dart';
import '../domain/transaction_repository.dart';

class CreateTransactionUseCase {
  CreateTransactionUseCase({
    TransactionRepository? repository,
    AuthRepository? authRepository,
  })  : _repository = repository ?? TransactionRepositoryProvider.instance,
        _authRepository = authRepository ?? AuthRepositoryProvider.instance;

  final TransactionRepository _repository;
  final AuthRepository _authRepository;

  Future<void> execute({
    required String clientName,
    required String phone,
    required double amount,
    required String country,
    required String service,
  }) {
    final user = _authRepository.currentUser;
    if (user == null) {
      throw StateError('User must be logged in to create a transaction.');
    }

    final canCreate = switch (user.role) {
      AppRole.owner || AppRole.admin || AppRole.agent => true,
      AppRole.client => false,
    };

    if (!canCreate) {
      throw StateError(
          'User role ${user.role.name} cannot create transactions.');
    }

    return _repository.createTransaction(
      clientName: clientName,
      phone: phone,
      amount: amount,
      country: country,
      service: service,
    );
  }
}
