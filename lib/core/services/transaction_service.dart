import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('transactions');

  User get _user {
    final u = _auth.currentUser;
    if (u == null) throw Exception('Pa gen user konekte.');
    return u;
  }

  /// Kreye yon draft (retounen id doc la)
  Future<String> createDraft({
    required String type,
    required String customerName,
    required String customerPhone,
    required num amount,
    String? note,
  }) async {
    final u = _user;
    final id = AppIds.transaction(
      seed: '${u.uid}:$type:${DateTime.now().toIso8601String()}',
    );

    await _col.doc(id).set({
      'txId': id,
      'transactionId': id,
      'uid': u.uid,
      'email': u.email,
      'type': type,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'amount': amount,
      'note': note,
      'status': 'draft',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return id;
  }

  /// Soumt draft la (chanje status)
  Future<void> submit({
    required String id,
  }) async {
    _user;

    await _col.doc(id).set({
      'status': 'submitted',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> myTransactionsStream() {
    final u = _auth.currentUser;
    if (u == null) return const Stream.empty();

    return _col
        .where('uid', isEqualTo: u.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }
}
