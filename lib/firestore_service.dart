import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

    await _db.collection('users').doc(userId).set({
      'uid': userId,
      'phone': phone ?? '',
      'role': 'agent',
      'balance': 0,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 2) Kreye Transaction (AUTO ID) -> /transactions/{txId}
  Future<String> createTransaction({
    required num amount,
  }) async {
    final userId = uid;

    final docRef = await _db.collection('transactions').add({
      'agentId': userId, //  sa dwe menm ak auth.uid
      'amount': amount, // number
      'status': 'created', // created|processing|completed
      'completeRequested': false, // boolean
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id; // txId
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
