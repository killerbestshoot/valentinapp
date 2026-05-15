import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _txCol =>
      _db.collection('transactions');

  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw Exception('User not logged in');
    }
  
    return u.uid;
  }

  Future<void> addTransaction({
    required double amount,
    required String senderName,
    required String receiverName,
    required String provider, // "Western Union" / "Cam Transfer"
    String? note,
  }) async {
    final now = Timestamp.now();
    await _txCol.add({
      'amount': amount,
      'senderName': senderName.trim(),
      'receiverName': receiverName.trim(),
      'provider': provider.trim(),
      'note': (note ?? '').trim(),
      'agentId': _uid,
      'createdAt': now,
      'status': 'created',
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyTransactions() {
    return _txCol
        .where('agentId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAllTransactions() {
    return _txCol.orderBy('createdAt', descending: true).snapshots();
  }
}
