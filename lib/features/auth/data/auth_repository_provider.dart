import '../../../core/config/app_environment.dart';
import '../domain/auth_repository.dart';
import 'http_auth_repository.dart';
import 'mock_auth_repository.dart';

class AuthRepositoryProvider {
  AuthRepositoryProvider._();

  static AuthRepository? _override;

  /// Pou tès yo, menm jan ak lòt API yo.
  static void override(AuthRepository repository) => _override = repository;
  static void reset() => _override = null;

  static AuthRepository get instance {
    if (_override != null) return _override!;
    if (AppEnvironment.mockFirebase) {
      return MockAuthRepository.instance;
    }
    return HttpAuthRepository.instance;
  }
}
