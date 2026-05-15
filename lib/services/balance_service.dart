import 'package:cloud_firestore/cloud_firestore.dart';

class BalanceService {
  BalanceService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String ownerDocId(String enterpriseId) {
    return '${enterpriseId}_OWNER';
  }

  static String staffDocId({
    required String enterpriseId,
    required String uid,
  }) {
    return '${enterpriseId}_$uid';
  }

  static DocumentReference<Map<String, dynamic>> ownerBalanceRef({
    required String enterpriseId,
  }) {
    return _db.collection('balances').doc(ownerDocId(enterpriseId));
  }

  static DocumentReference<Map<String, dynamic>> staffBalanceRef({
    required String enterpriseId,
    required String uid,
  }) {
    return _db.collection('balances').doc(staffDocId(
      enterpriseId: enterpriseId,
      uid: uid,
    ));
  }

  static Future<void> ensureOwnerBalance({
    required String enterpriseId,
    required String enterpriseName,
    required String ownerUid,
    String currency = 'USD',
  }) async {
    final ref = ownerBalanceRef(enterpriseId: enterpriseId);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': ownerUid,
        'role': 'owner',
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'balance': 0,
        'currency': currency,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> ensureStaffBalance({
    required String enterpriseId,
    required String enterpriseName,
    required String uid,
    required String role,
    String currency = 'USD',
  }) async {
    final ref = staffBalanceRef(
      enterpriseId: enterpriseId,
      uid: uid,
    );
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': uid,
        'role': role,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'balance': 0,
        'currency': currency,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  static Future<void> addToBalance({
    required DocumentReference<Map<String, dynamic>> ref,
    required num amount,
  }) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final current = ((data['balance'] ?? 0) as num).toDouble();
      final next = current + amount.toDouble();

      tx.set(ref, {
        ...data,
        'balance': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<void> subtractFromBalance({
    required DocumentReference<Map<String, dynamic>> ref,
    required num amount,
  }) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final current = ((data['balance'] ?? 0) as num).toDouble();
      final next = current - amount.toDouble();

      if (next < 0) {
        throw Exception('Insufficient balance');
      }

      tx.set(ref, {
        ...data,
        'balance': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}