enum UserRole {
  owner,
  admin,
  agent,
  client;

  String get value => name;

  static UserRole fromString(String? v) {
    switch (v) {
      case 'owner':
        return UserRole.owner;
      case 'admin':
        return UserRole.admin;
      case 'agent':
        return UserRole.agent;
      default:
        return UserRole.client;
    }
  }
}
