import '../data/auth_repository_provider.dart';
import '../domain/auth_repository.dart';
import '../models/auth_user.dart';

class LoginUseCase {
  LoginUseCase({AuthRepository? repository})
      : _repository = repository ?? AuthRepositoryProvider.instance;

  final AuthRepository _repository;

  Future<AuthUser> execute({required String email, required String password}) {
    return _repository.signIn(email: email, password: password);
  }

  Future<AuthUser> signUp({required String email, required String password}) {
    return _repository.signUp(email: email, password: password);
  }

  AuthUser? get currentUser => _repository.currentUser;

  Stream<AuthUser?> authStateChanges() => _repository.authStateChanges();

  Future<void> signOut() => _repository.signOut();
}
