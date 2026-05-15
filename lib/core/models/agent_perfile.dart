class AgentProfile {
  final String status; // pending | approved | suspended | banned
  final num balance;
  final num commissionRate;
  final String name;
  final String phone;

  AgentProfile({
    required this.status,
    required this.balance,
    required this.commissionRate,
    required this.name,
    required this.phone,
  });

  static AgentProfile? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;
    return AgentProfile(
      status: (data['status'] ?? 'pending').toString(),
      balance: (data['balance'] ?? 0) as num,
      commissionRate: (data['commissionRate'] ?? 0) as num,
      name: (data['name'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
    );
  }
}
