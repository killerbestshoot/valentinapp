import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mon_premye_app/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await FirebaseFirestore.instance
      .collection('users')
      .doc('NsnXe66Z1WhfUWy0DePpmT9uE3g2')
      .set({
    'uid': 'NsnXe66Z1WhfUWy0DePpmT9uE3g2',
    'email': 'owner@test.com',
    'displayName': 'Owner',
    'fullName': 'Owner',
    'role': 'owner',
    'enterpriseId': 'ENT-001',
    'enterpriseName': 'VOUPVAPCASH',
    'isActive': true,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  print('USER FIXED: NsnXe66Z1WhfUWy0DePpmT9uE3g2');
}
