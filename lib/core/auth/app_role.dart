enum AppRole { admin, agent }

AppRole appRoleFromString(String? v) {
  switch ((v ?? '').toLowerCase()) {
    case 'admin':
      return AppRole.admin;
    case 'agent':
    default:
      return AppRole.agent;
  }
}

String appRoleToString(AppRole role) => role.name;
