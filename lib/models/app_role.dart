class AppRole {
  final String role; // owner | admin | agent
  final bool active;

  AppRole({required this.role, required this.active});

  static AppRole? fromMap(Map<String, dynamic>? data) {
    if (data == null) return null;

    return AppRole(
      role: (data['role'] ?? '').toString(),
      active: (data['active'] ?? true) == true,
    );
  }
}
