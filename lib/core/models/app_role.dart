enum AppRole {
  owner,
  admin,
  agent,
  client,
}

extension AppRoleX on AppRole {
  String get label {
    switch (this) {
      case AppRole.owner:
        return 'Pwopriyet';
      case AppRole.admin:
        return 'Administrat';
      case AppRole.agent:
        return 'Ajan';
      case AppRole.client:
        return 'Kliyan';
    }
  }

  String get description {
    switch (this) {
      case AppRole.owner:
        return 'Mt antrepriz la, w tout sistm nan ak done yo.';
      case AppRole.admin:
        return 'Jere operasyon, ekip ak sipvizyon svis yo.';
      case AppRole.agent:
        return 'Antre tranzaksyon epi svi kliyan yo.';
      case AppRole.client:
        return 'Moun k ap resevwa svis sou platfm nan.';
    }
  }

  static AppRole fromString(String raw) {
    final value = raw.trim().toLowerCase();

    switch (value) {
      case 'owner':
        return AppRole.owner;
      case 'admin':
      case 'administrator':
        return AppRole.admin;
      case 'agent':
        return AppRole.agent;
      case 'client':
        return AppRole.client;
      default:
        return AppRole.agent;
    }
  }

  String get firestoreValue {
    switch (this) {
      case AppRole.owner:
        return 'owner';
      case AppRole.admin:
        return 'admin';
      case AppRole.agent:
        return 'agent';
      case AppRole.client:
        return 'client';
    }
  }
}
