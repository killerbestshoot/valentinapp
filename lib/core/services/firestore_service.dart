import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> col(String name) =>
      db.collection(name);
  DocumentReference<Map<String, dynamic>> doc(String colName, String id) =>
      db.collection(colName).doc(id);
}
