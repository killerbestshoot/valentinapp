import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/firebase_refs.dart';
import '../models/role.dart';
import 'package:mon_premye_app/services/shared/app_ids.dart';

class UserService {
  UserService._();
  static final UserService instance = UserService._();

  /// Kreye user profile + wallet otomatikman (1 sl operasyon atomic)
  Future<void> ensureUserProfileAndWallet({
    required String uid,
    required String email,
    UserRole defaultRole = UserRole.client,
  }) async {
    final userDoc = FirebaseRefs.users().doc(uid);
    final walletDoc = FirebaseRefs.wallets().doc(uid);

    final snap = await userDoc.get();
    if (snap.exists) {
      // deja kreye
      return;
    }

    final batch = FirebaseFirestore.instance.batch();

    batch.set(userDoc, {
      'uid': uid,
      'authUid': uid,
      'userId': AppIds.userForRole(defaultRole.value, seed: uid),
      'email': email,
      'role': defaultRole.value,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });

    batch.set(walletDoc, {
      'uid': uid,
      'balance': 0,
      'currency': 'HTG',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<UserRole> getUserRole(String uid) async {
    final doc = await FirebaseRefs.users().doc(uid).get();
    final data = doc.data();
    return UserRole.fromString(data?['role'] as String?);
  }
}
