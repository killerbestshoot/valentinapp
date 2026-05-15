import 'package:cloud_firestore/cloud_firestore.dart';

class UserStatusService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> getUserStatus(String uid) async {
    final id = uid.trim();
    if (id.isEmpty) {
      return {
        'uid': '',
        'isActive': false,
        'displayName': '',
        'role': '',
      };
    }

    final snap = await _db.collection('users').doc(id).get();
    final data = snap.data() ?? <String, dynamic>{};

    return {
      'uid': id,
      'isActive': data['isActive'] is bool ? data['isActive'] as bool : true,
      'displayName': (data['displayName'] ?? data['fullName'] ?? '').toString(),
      'role': (data['role'] ?? '').toString(),
    };
  }

  static Future<bool> isUserActive(String uid) async {
    final data = await getUserStatus(uid);
    return data['isActive'] == true;
  }
}