import 'package:flutter/material.dart';

import '../../auth/data/auth_repository_provider.dart';
import '../domain/dashboard_repository.dart';
import '../models/dashboard_data.dart';
import '../models/service_offer.dart';

class MockDashboardRepository implements DashboardRepository {
  MockDashboardRepository._();
  static final MockDashboardRepository instance = MockDashboardRepository._();

  @override
  Future<DashboardData> loadDashboardData() async {
    final user = AuthRepositoryProvider.instance.currentUser;
    return DashboardData(
      email: user?.email ?? 'mock@local.test',
      services: _services,
    );
  }

  static const List<ServiceOffer> _services = [
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
