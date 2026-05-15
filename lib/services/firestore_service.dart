import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> roleDoc(String uid) =>
      _db.collection('roles').doc(uid);

  DocumentReference<Map<String, dynamic>> agentDoc(String uid) =>
      _db.collection('agents').doc(uid);

  DocumentReference<Map<String, dynamic>> settingsGlobalDoc() =>
      _db.collection('settings').doc('global');

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRole(String uid) =>
      roleDoc(uid).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchAgent(String uid) =>
      agentDoc(uid).snapshots();

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSettings() =>
      settingsGlobalDoc().snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyTransactions(String uid) {
    return _db
        .collection('transactions')
        .where('agentUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<void> createTransactionRequest({
    required String agentUid,
    required String type,
    required int amount,
    required String customerRef,
  }) async {
    await _db.collection('transaction_requests').add({
      'agentUid': agentUid,
      'type': type,
      'amount': amount,
      'customerRef': customerRef,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'queued',
    });
  }
}
