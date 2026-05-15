import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthGuardService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<bool> hasValidUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return false;

    final data = doc.data();
    if (data == null) return false;

    final role = (data['role'] ?? '').toString().trim();
    final enterpriseId = (data['enterpriseId'] ?? '').toString().trim();
    final isActiveRaw = data['isActive'];
    final isActive = isActiveRaw is bool ? isActiveRaw : true;

    if (role.isEmpty) return false;
    if (enterpriseId.isEmpty) return false;
    if (!isActive) return false;

    return true;
  }

  static Future<bool> validateCurrentUserOrSignOut() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final ok = await hasValidUserProfile(user.uid);
    if (!ok) {
      await _auth.signOut();
      return false;
    }
    return true;
  }
}