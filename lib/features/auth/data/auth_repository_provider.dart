import '../../../core/config/app_environment.dart';
import '../domain/auth_repository.dart';
import 'http_auth_repository.dart';
import 'mock_auth_repository.dart';

class AuthRepositoryProvider {
  AuthRepositoryProvider._();

  static AuthRepository get instance {
    if (AppEnvironment.mockFirebase) {
      return MockAuthRepository.instance;
    }
    return HttpAuthRepository.instance;
  }
}
