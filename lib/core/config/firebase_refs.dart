import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseRefs {
  FirebaseRefs._();
  static final db = FirebaseFirestore.instance;

  // Collections
  static CollectionReference<Map<String, dynamic>> users() =>
      db.collection('users');
  static CollectionReference<Map<String, dynamic>> wallets() =>
      db.collection('wallets');
  static CollectionReference<Map<String, dynamic>> agents() =>
      db.collection('agents');
  static CollectionReference<Map<String, dynamic>> transactions() =>
      db.collection('transactions');
}
