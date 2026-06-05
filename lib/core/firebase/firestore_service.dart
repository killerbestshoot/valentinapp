import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class FirestoreService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String get uid {
    final u = _auth.currentUser;
    if (u == null) throw Exception("Pa konekte. F login avan.");
    return u.uid;
  }

  String? get phone => _auth.currentUser?.phoneNumber;

  /// 1) Ekri users/{uid}
  Future<void> writeUserDoc() async {
    final userId = uid;
    final ref = _db.collection('users').doc(userId);
    final snap = await ref.get();
    final data = snap.data() ?? <String, dynamic>{};
    final existingAppUserId = (data['userId'] ?? '').toString();

    await ref.set({
      'uid': userId,
      'authUid': userId,
      'userId': AppIds.isPrefixedUuid5(existingAppUserId)
          ? existingAppUserId
          : AppIds.agent(seed: userId),
      'phone': phone ?? '',
      'role': 'agent',
      'balance': 0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 2) Kreye Transaction -> /transactions/{TX_uuid5}
  Future<String> createTransaction({
    required num amount,
  }) async {
    final userId = uid;

    final txId = AppIds.transaction(
      seed: '$userId:${DateTime.now().toIso8601String()}',
    );

    await _db.collection('transactions').doc(txId).set({
      'txId': txId,
      'transactionId': txId,
      'agentId': userId, //  sa dwe menm ak auth.uid
      'amount': amount, // number
      'status': 'created', // created|processing|completed
      'completeRequested': false, // boolean
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return txId;
  }

  /// 3) Li dnye transaction pou agent sa
  Future<Map<String, dynamic>?> getLatestTransaction() async {
    final userId = uid;

    final qs = await _db
        .collection('transactions')
        .where('agentId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (qs.docs.isEmpty) return null;

    final d = qs.docs.first;
    return {
      'id': d.id,
      ...d.data(),
    };
  }

  /// 4) Chanje status yon tx (created->processing->completed)
  Future<void> updateTransactionStatus({
    required String txId,
    required String status, // created|processing|completed
  }) async {
    await _db.collection('transactions').doc(txId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bonus: mande "completeRequested" true/false
  Future<void> setCompleteRequested({
    required String txId,
    required bool value,
  }) async {
    await _db.collection('transactions').doc(txId).update({
      'completeRequested': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
