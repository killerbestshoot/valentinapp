import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';
import 'package:mon_premye_app/features/transactions/domain/create_transaction_use_case.dart';
import 'package:mon_premye_app/features/transactions/domain/transaction_repository.dart';
import 'package:mon_premye_app/features/transactions/models/transaction_model.dart';

void main() {
  group('CreateTransactionUseCase role access', () {
    test('owner can create a transaction', () async {
      final repository = _FakeTransactionRepository();
      final useCase = _useCaseFor(AppRole.owner, repository);

      await useCase.execute(
        clientName: 'Owner Client',
        phone: '50900000000',
        amount: 25,
        country: 'HT',
        service: 'MonCash',
      );

      expect(repository.created.length, 1);
      expect(repository.created.single.clientName, 'Owner Client');
    });

    test('admin can create a transaction', () async {
      final repository = _FakeTransactionRepository();
      final useCase = _useCaseFor(AppRole.admin, repository);

      await useCase.execute(
        clientName: 'Admin Client',
        phone: '50911111111',
        amount: 50,
        country: 'HT',
        service: 'NatCash',
      );

      expect(repository.created.length, 1);
      expect(repository.created.single.clientName, 'Admin Client');
    });

    test('agent can create a transaction', () async {
      final repository = _FakeTransactionRepository();
      final useCase = _useCaseFor(AppRole.agent, repository);

      await useCase.execute(
        clientName: 'Agent Client',
        phone: '50922222222',
        amount: 75,
        country: 'HT',
        service: 'Western Union',
      );

      expect(repository.created.length, 1);
      expect(repository.created.single.clientName, 'Agent Client');
    });

    test('client cannot create a transaction', () async {
      final repository = _FakeTransactionRepository();
      final useCase = _useCaseFor(AppRole.client, repository);

      expect(
        () => useCase.execute(
          clientName: 'Client User',
          phone: '50933333333',
          amount: 100,
          country: 'HT',
          service: 'CAM Transf',
        ),
        throwsStateError,
      );
      expect(repository.created, isEmpty);
    });

    test('signed-out user cannot create a transaction', () async {
      final repository = _FakeTransactionRepository();
      final useCase = CreateTransactionUseCase(
        repository: repository,
        authRepository: _FakeAuthRepository(null),
      );

      expect(
        () => useCase.execute(
          clientName: 'No Session',
          phone: '50944444444',
          amount: 100,
          country: 'HT',
          service: 'MonCash',
        ),
        throwsStateError,
      );
      expect(repository.created, isEmpty);
    });
  });
}

CreateTransactionUseCase _useCaseFor(
  AppRole role,
  _FakeTransactionRepository repository,
) {
  return CreateTransactionUseCase(
    repository: repository,
    authRepository: _FakeAuthRepository(
      AuthUser(
        uid: '${role.name}-uid',
        email: '${role.name}@test.com',
        role: role,
      ),
    ),
  );
}

class _CreatedTransaction {
  const _CreatedTransaction({
    required this.clientName,
    required this.phone,
    required this.amount,
    required this.country,
    required this.service,
  });

  final String clientName;
  final String phone;
  final double amount;
  final String country;
  final String service;
}

class _FakeTransactionRepository implements TransactionRepository {
  final List<_CreatedTransaction> created = <_CreatedTransaction>[];

  @override
  Future<void> createTransaction({
    required String clientName,
    required String phone,
    required double amount,
    required String country,
    required String service,
  }) async {
    created.add(
      _CreatedTransaction(
        clientName: clientName,
        phone: phone,
        amount: amount,
        country: country,
        service: service,
      ),
    );
  }

  @override
  Stream<List<TransactionModel>> watchTransactions() {
    return const Stream<List<TransactionModel>>.empty();
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.currentUser);

  @override
  final AuthUser? currentUser;

  @override
  Stream<AuthUser?> authStateChanges() {
    return Stream<AuthUser?>.value(currentUser);
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}
}
