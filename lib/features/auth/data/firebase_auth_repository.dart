import 'package:firebase_auth/firebase_auth.dart';

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
    return AuthUser(uid: user.uid, email: user.email ?? '');
  }

  @override
  Future<AuthUser> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Unable to sign in user.');
    }

    return AuthUser(uid: user.uid, email: user.email ?? '');
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
