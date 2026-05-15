import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> seedServices() async {
  final fs = FirebaseFirestore.instance;

  final allowed = <String>{
    'moncash_ht',
    'natcash_ht',
    'minutes_topup',
  };

  final seed = [
    {
      'id': 'moncash_ht',
      'name': 'MonCash',
      'category': 'wallet',
      'country': 'HT',
      'code': 'MONCASH',
      'enterpriseId': 'ENT-001',
      'active': true,
    },
    {
      'id': 'natcash_ht',
      'name': 'NatCash',
      'category': 'wallet',
      'country': 'HT',
      'code': 'NATCASH',
      'enterpriseId': 'ENT-001',
      'active': true,
    },
    {
      'id': 'minutes_topup',
      'name': 'Topup Minutes',
      'category': 'topup',
      'country': 'HT',
      'code': 'MINIT',
      'enterpriseId': 'ENT-001',
      'active': true,
    },
  ];

  for (final s in seed) {
    await fs.collection('services').doc(s['id'] as String).set({
      'name': s['name'],
      'category': s['category'],
      'country': s['country'],
      'code': s['code'],
      'enterpriseId': s['enterpriseId'],
      'active': s['active'],
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  final all = await fs.collection('services').get();
  for (final d in all.docs) {
    if (!allowed.contains(d.id)) {
      await d.reference.set({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final data = d.data();
      await d.reference.set({
        'active': true,
        'category': (data['category'] ?? '').toString().toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  debugPrint('SERVICES NORMALIZED ');
}