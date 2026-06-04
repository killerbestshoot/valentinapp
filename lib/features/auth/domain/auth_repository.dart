import '../models/auth_user.dart';

abstract class AuthRepository {
  AuthUser? get currentUser;

  Future<AuthUser> signIn({required String email, required String password});
  Future<void> signOut();
}
