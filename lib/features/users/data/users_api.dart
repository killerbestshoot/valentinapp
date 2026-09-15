import '../../../core/network/api_client.dart';

/// Yon staff nan antrepriz la, ak sòld wallet li.
class StaffMember {
  const StaffMember({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    required this.balance,
    required this.currency,
    this.enterpriseId = '',
    this.enterpriseName = '',
  });

  final String uid;
  final String email;
  final String displayName;
  final String role;
  final bool isActive;
  final double balance;
  final String currency;
  final String enterpriseId;
  final String enterpriseName;

  String get label => displayName.isEmpty ? email : displayName;

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      uid: '${json['uid'] ?? ''}',
      email: '${json['email'] ?? ''}',
      displayName: '${json['displayName'] ?? ''}',
      role: '${json['role'] ?? 'agent'}',
      isActive: json['isActive'] != false,
      balance: json['balance'] is num ? (json['balance'] as num).toDouble() : 0,
      currency: '${json['currency'] ?? 'USD'}',
      enterpriseId: '${json['enterpriseId'] ?? ''}',
      enterpriseName: '${json['enterpriseName'] ?? ''}',
    );
  }
}

/// Jesyon staff — ranplase `collection('users')` ak `collection('enterprise_users')`.
class UsersApi {
  UsersApi({ApiClient? client}) : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  static UsersApi? _instance;
  static UsersApi get instance => _instance ??= UsersApi();

  static void override(UsersApi api) => _instance = api;
  static void reset() => _instance = null;

  Future<List<StaffMember>> list({String? role}) async {
    final json = await _client.get('/api/users', query: {
      if (role != null && role.isNotEmpty) 'role': role,
    });

    final items = (json['users'] as List?) ?? const [];
    return items
        .map((item) => StaffMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Kreye yon staff. Kontrèman ak Firebase, sa PA dekonekte moun k ap kreye a.
  ///
  /// `currency` se deviz wallet la — li pa ka chanje apre, donk chwazi l byen.
  Future<StaffMember> create({
    required String email,
    required String password,
    required String displayName,
    String role = 'agent',
    String currency = 'USD',
  }) async {
    final json = await _client.post('/api/users', {
      'email': email,
      'password': password,
      'displayName': displayName,
      'role': role,
      'currency': currency,
    });

    return StaffMember.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<StaffMember> setActive(String uid, bool isActive) async {
    final json = await _client.patch('/api/users/$uid', {'isActive': isActive});
    return StaffMember.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<StaffMember> setRole(String uid, String role) async {
    final json = await _client.patch('/api/users/$uid', {'role': role});
    return StaffMember.fromJson(json['user'] as Map<String, dynamic>);
  }

  Future<void> resetPassword(String uid, String password) async {
    await _client.post('/api/users/$uid/password', {'password': password});
  }
}
