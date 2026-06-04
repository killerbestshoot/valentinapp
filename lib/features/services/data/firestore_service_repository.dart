import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/persistence/firebase_persistence.dart';
import '../domain/service_repository.dart';
import '../models/service_model.dart';

class FirestoreServiceRepository implements ServiceRepository {
  FirestoreServiceRepository._();
  static final FirestoreServiceRepository instance = FirestoreServiceRepository._();

  final FirebaseFirestore _firestore = FirebasePersistence.instance.firestore;

  CollectionReference<Map<String, dynamic>> get _services =>
      _firestore.collection('services');

  @override
  Future<List<ServiceModel>> loadServices() async {
    try {
      final snapshot = await _services.get();
      if (snapshot.docs.isEmpty) {
        return _fallbackServices;
      }

      return snapshot.docs
          .map((doc) => ServiceModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return _fallbackServices;
    }
  }

  static const List<ServiceModel> _fallbackServices = [
    ServiceModel(
      id: 'moncash_ht',
      name: 'MonCash',
      category: 'topup',
      icon: 'wallet',
    ),
    ServiceModel(
      id: 'natcash_ht',
      name: 'NatCash',
      category: 'topup',
      icon: 'payments',
    ),
    ServiceModel(
      id: 'minutes_topup',
      name: 'Minutes Topup',
      category: 'topup',
      icon: 'public',
    ),
  ];
}
