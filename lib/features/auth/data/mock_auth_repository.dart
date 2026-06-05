import 'dart:async';

import '../../../core/models/app_role.dart';
import '../domain/auth_repository.dart';
import '../models/auth_user.dart';

class MockAuthRepository implements AuthRepository {
  MockAuthRepository._();
  static final MockAuthRepository instance = MockAuthRepository._();

  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();
  final Map<String, String> _passwordsByEmail = <String, String>{};
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() {
    return _authStateController.stream;
  }

  @override
  Future<AuthUser> signIn(
      {required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    final existingPassword = _passwordsByEmail[normalizedEmail];
    if (existingPassword != null && existingPassword != password) {
      throw StateError('Modpas mock la pa bon.');
    }

    _passwordsByEmail[normalizedEmail] = password;
    return _setCurrentUser(normalizedEmail);
  }

  @override
  Future<AuthUser> signUp(
      {required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    _passwordsByEmail[normalizedEmail] = password;
    return _setCurrentUser(normalizedEmail);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStateController.add(null);
  }

  AuthUser _setCurrentUser(String email) {
    final user = AuthUser(
      uid: 'mock-${email.hashCode.abs()}',
      email: email,
      role: _roleForEmail(email),
    );
    _currentUser = user;
    _authStateController.add(user);
    return user;
  }

  AppRole _roleForEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.startsWith('owner@')) return AppRole.owner;
    if (normalizedEmail.startsWith('admin@') ||
        normalizedEmail.startsWith('administrator@')) {
      return AppRole.admin;
    }
    if (normalizedEmail.startsWith('client@')) return AppRole.client;
    return AppRole.agent;
  }
}
