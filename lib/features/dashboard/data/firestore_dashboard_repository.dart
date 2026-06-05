import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/persistence/firebase_persistence.dart';
import '../domain/dashboard_repository.dart';
import '../models/dashboard_data.dart';
import '../models/service_offer.dart';

class FirestoreDashboardRepository implements DashboardRepository {
  FirestoreDashboardRepository._();
  static final FirestoreDashboardRepository instance =
      FirestoreDashboardRepository._();

  final FirebaseFirestore _firestore = FirebasePersistence.instance.firestore;

  @override
  Future<DashboardData> loadDashboardData() async {
    final currentUser = FirebasePersistence.instance.auth.currentUser;
    final email = currentUser?.email ?? 'unknown@domain.com';

    final availableServices = await _loadServices();
    return DashboardData(email: email, services: availableServices);
  }

  Future<List<ServiceOffer>> _loadServices() async {
    try {
      final snapshot = await _firestore.collection('services').get();
      if (snapshot.docs.isEmpty) {
        return _fallbackServices;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final title = data['title']?.toString() ?? 'Unknown Service';
        final iconKey = data['icon']?.toString() ?? '';
        return ServiceOffer(
          id: doc.id,
          title: title,
          icon: _serviceIcon(iconKey, title),
        );
      }).toList();
    } catch (_) {
      return _fallbackServices;
    }
  }

  IconData _serviceIcon(String iconKey, String title) {
    switch (iconKey) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'payments':
        return Icons.payments;
      case 'public':
        return Icons.public;
      case 'swap':
        return Icons.swap_horiz;
      default:
        if (title.toLowerCase().contains('cash')) {
          return Icons.account_balance_wallet;
        }
        return Icons.miscellaneous_services;
    }
  }

  static const List<ServiceOffer> _fallbackServices = [
    ServiceOffer(
      id: 'mncash',
      title: 'MonCash',
      icon: Icons.account_balance_wallet,
    ),
    ServiceOffer(
      id: 'natcash',
      title: 'NatCash',
      icon: Icons.payments,
    ),
    ServiceOffer(
      id: 'wu',
      title: 'Western Union',
      icon: Icons.public,
    ),
    ServiceOffer(
      id: 'camtransf',
      title: 'CAM Transf',
      icon: Icons.swap_horiz,
    ),
  ];
}
