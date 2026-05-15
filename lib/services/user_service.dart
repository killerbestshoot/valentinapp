import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final _db = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> upsertCurrentUser({String role = 'agent'}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ref = userDoc(user.uid);

    await ref.set({
      'uid': user.uid,
      'phone': user.phoneNumber,
      'role': role,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> watchCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return userDoc(user.uid).snapshots().map((s) => s.data());
  }
}
