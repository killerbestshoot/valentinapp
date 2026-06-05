import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/auth/data/mock_auth_repository.dart';

void main() {
  group('MockAuthRepository', () {
    test('derives owner role from owner email', () async {
      final repository = MockAuthRepository.instance;
      addTearDown(repository.signOut);

      final user = await repository.signIn(
        email: 'owner@example.test',
        password: 'secret123',
      );

      expect(user.role, AppRole.owner);
      expect(repository.currentUser?.email, 'owner@example.test');
    });

    test('derives admin role from admin email', () async {
      final repository = MockAuthRepository.instance;
      addTearDown(repository.signOut);

      final user = await repository.signIn(
        email: 'admin@example.test',
        password: 'secret123',
      );

      expect(user.role, AppRole.admin);
    });

    test('derives admin role from administrator email', () async {
      final repository = MockAuthRepository.instance;
      addTearDown(repository.signOut);

      final user = await repository.signIn(
        email: 'administrator@example.test',
        password: 'secret123',
      );

      expect(user.role, AppRole.admin);
    });

    test('emits auth state changes on login and logout', () async {
      final repository = MockAuthRepository.instance;
      addTearDown(repository.signOut);

      final authStates = repository.authStateChanges();
      final expectation = expectLater(
        authStates,
        emitsInOrder([
          isA<Object>(),
          isNull,
        ]),
      );

      await repository.signIn(
        email: 'agent@example.test',
        password: 'secret123',
      );
      await repository.signOut();

      await expectation;
    });
  });
}
