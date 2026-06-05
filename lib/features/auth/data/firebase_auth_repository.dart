import 'package:firebase_auth/firebase_auth.dart';

import '../../../app/admin_config.dart';
import '../../../core/models/app_role.dart';
import '../../../core/persistence/firebase_persistence.dart';
import '../domain/auth_repository.dart';
import '../models/auth_user.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository._();
  static final FirebaseAuthRepository instance = FirebaseAuthRepository._();

  final FirebaseAuth _auth = FirebasePersistence.instance.auth;

  @override
  AuthUser? get currentUser {
    final user = _auth.currentUser;
    if (user == null) return null;
    final email = user.email ?? '';
    return AuthUser(uid: user.uid, email: email, role: _roleForEmail(email));
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _auth.authStateChanges().map((user) {
      if (user == null) return null;
      final email = user.email ?? '';
      return AuthUser(uid: user.uid, email: email, role: _roleForEmail(email));
    });
  }

  @override
  Future<AuthUser> signIn(
      {required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Unable to sign in user.');
    }

    final userEmail = user.email ?? '';
    return AuthUser(
        uid: user.uid, email: userEmail, role: _roleForEmail(userEmail));
  }

  @override
  Future<AuthUser> signUp(
      {required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Unable to create user.');
    }

    final userEmail = user.email ?? '';
    return AuthUser(
        uid: user.uid, email: userEmail, role: _roleForEmail(userEmail));
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AppRole _roleForEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail == AdminConfig.adminEmail.toLowerCase()) {
      return AppRole.admin;
    }
    if (normalizedEmail.startsWith('administrator@') ||
        normalizedEmail.startsWith('admin@')) {
      return AppRole.admin;
    }
    if (normalizedEmail.startsWith('owner@')) {
      return AppRole.owner;
    }
    return AppRole.agent;
  }
}
