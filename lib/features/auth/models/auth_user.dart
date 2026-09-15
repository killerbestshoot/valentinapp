import '../../../core/models/app_role.dart';

class AuthUser {
  final String uid;
  final String email;
  final AppRole role;

  /// Chan sa yo vin ak backend SQLite la. Yo gen yon valè pa default pou
  /// ansyen kòd la kontinye konpile.
  final String displayName;
  final String enterpriseId;
  final String enterpriseName;
  final bool mustChangePassword;

  const AuthUser({
    required this.uid,
    required this.email,
    this.role = AppRole.agent,
    this.displayName = '',
    this.enterpriseId = '',
    this.enterpriseName = '',
    this.mustChangePassword = false,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      uid: '${json['uid'] ?? ''}',
      email: '${json['email'] ?? ''}',
      role: AppRoleX.fromString('${json['role'] ?? 'agent'}'),
      displayName: '${json['displayName'] ?? ''}',
      enterpriseId: '${json['enterpriseId'] ?? ''}',
      enterpriseName: '${json['enterpriseName'] ?? ''}',
      mustChangePassword: json['mustChangePassword'] == true,
    );
  }
}
