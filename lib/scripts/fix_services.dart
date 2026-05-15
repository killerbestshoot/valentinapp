import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> fixServices() async {
  final fs = FirebaseFirestore.instance;

  final doc = fs.collection('services').doc('minutes_topup');

  await doc.set({
    'name': 'Topup Minutes',
    'category': 'topup',
    'code': 'MINIT',
    'enterpriseId': 'ENT-001',
    'active': true,
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  debugPrint('SERVICE FIXED ');
}
