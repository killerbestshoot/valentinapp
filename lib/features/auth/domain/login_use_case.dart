import '../data/firebase_auth_repository.dart';
import '../domain/auth_repository.dart';
import '../models/auth_user.dart';

class LoginUseCase {
  LoginUseCase({AuthRepository? repository})
      : _repository = repository ?? FirebaseAuthRepository.instance;

  final AuthRepository _repository;

  Future<AuthUser> execute({required String email, required String password}) {
    return _repository.signIn(email: email, password: password);
  }

  AuthUser? get currentUser => _repository.currentUser;

  Future<void> signOut() => _repository.signOut();
}
