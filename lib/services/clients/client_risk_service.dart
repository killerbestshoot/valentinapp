import 'package:cloud_firestore/cloud_firestore.dart';

class ClientRiskService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> getClientFlag(String phone) async {
    final clean = phone.trim();
    if (clean.isEmpty) {
      return {
        'phone': '',
        'status': 'normal',
        'note': '',
      };
    }

    final snap = await _db.collection('client_flags').doc(clean).get();
    final data = snap.data() ?? <String, dynamic>{};

    return {
      'phone': clean,
      'status': (data['status'] ?? 'normal').toString(),
      'note': (data['note'] ?? '').toString(),
    };
  }

  static Future<bool> isBlacklisted(String phone) async {
    final data = await getClientFlag(phone);
    return (data['status'] ?? 'normal').toString() == 'blacklist';
  }

  static Future<bool> isWatchlist(String phone) async {
    final data = await getClientFlag(phone);
    return (data['status'] ?? 'normal').toString() == 'watchlist';
  }
}
