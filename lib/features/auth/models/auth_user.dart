import '../../../core/models/app_role.dart';

class AuthUser {
  final String uid;
  final String email;
  final AppRole role;

  const AuthUser({
    required this.uid,
    required this.email,
    this.role = AppRole.agent,
  });
}
