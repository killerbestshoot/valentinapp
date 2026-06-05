import 'package:cloud_firestore/cloud_firestore.dart';

class EnterpriseStatusService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> getEnterpriseStatus(
      String enterpriseId) async {
    final id = enterpriseId.trim();
    if (id.isEmpty) {
      return {
        'enterpriseId': '',
        'isActive': false,
        'name': '',
      };
    }

    final snap = await _db.collection('enterprises').doc(id).get();
    final data = snap.data() ?? <String, dynamic>{};

    return {
      'enterpriseId': id,
      'isActive': data['isActive'] is bool ? data['isActive'] as bool : true,
      'name': (data['name'] ?? data['enterpriseName'] ?? id).toString(),
    };
  }

  static Future<bool> isEnterpriseActive(String enterpriseId) async {
    final data = await getEnterpriseStatus(enterpriseId);
    return data['isActive'] == true;
  }
}
