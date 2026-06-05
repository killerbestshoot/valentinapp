class LocalProfileStore {
  LocalProfileStore._();

  static final LocalProfileStore instance = LocalProfileStore._();

  final Map<String, Map<String, dynamic>> _profiles = {};

  Future<Map<String, dynamic>?> load(String authUid) async {
    return _profiles[authUid];
  }

  Future<void> save(String authUid, Map<String, dynamic> profile) async {
    _profiles[authUid] = Map<String, dynamic>.from(profile);
  }
}
