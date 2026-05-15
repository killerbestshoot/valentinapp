import 'package:cloud_firestore/cloud_firestore.dart';
import 'role.dart';

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final Timestamp createdAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'role': role.value,
        'createdAt': createdAt,
      };

  static AppUser fromMap(Map<String, dynamic> map) => AppUser(
        uid: (map['uid'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        role: UserRole.fromString(map['role'] as String?),
        createdAt: (map['createdAt'] as Timestamp?) ?? Timestamp.now(),
      );
}
