import '../models/app_role.dart';

class AppSession {
  static bool isLoggedIn = false;
  static AppRole currentRole = AppRole.agent;
  static String currentUserId = '';
  static String currentUserName = 'Ajan';
  static String currentUserEmail = '';
  static String enterpriseName = 'MonCash Enterprise';
  static String enterpriseId = 'ENT-001';
  static bool isActive = true;

  static void apply({
    required String userId,
    required String userName,
    required String userEmail,
    required AppRole role,
    required String enterprise,
    required String enterpriseUid,
    required bool active,
  }) {
    isLoggedIn = true;
    currentUserId = userId;
    currentUserName = userName;
    currentUserEmail = userEmail;
    currentRole = role;
    enterpriseName = enterprise;
    enterpriseId = enterpriseUid;
    isActive = active;
  }

  static void logout() {
    isLoggedIn = false;
    currentRole = AppRole.agent;
    currentUserId = '';
    currentUserName = 'Ajan';
    currentUserEmail = '';
    enterpriseName = 'MonCash Enterprise';
    enterpriseId = 'ENT-001';
    isActive = true;
  }

  static void clear() {
    logout();
  }
}
