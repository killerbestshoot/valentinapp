import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/domain/login_use_case.dart';
import '../../../dashboard/domain/get_dashboard_data_use_case.dart';
import '../../../dashboard/models/dashboard_data.dart';
import '../../../dashboard/presentation/widgets/service_button.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GetDashboardDataUseCase _dashboardUseCase = GetDashboardDataUseCase();
  final LoginUseCase _authUseCase = LoginUseCase();
  DashboardData? _data;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dashboardData = await _dashboardUseCase.execute();
      if (!mounted) return;
      setState(() {
        _data = dashboardData;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authUseCase.signOut();
    if (!mounted) return;
    context.go('/');
  }

  void _goToService(String serviceTitle) {
    final service = Uri.encodeComponent(serviceTitle);
    context.go('/tx/new?service=$service');
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Chajman dashboard echwe: $_error'),
        ),
      );
    }

    final data = _data!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Salon Dashboard',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text('Email: ${data.email}'),
        const SizedBox(height: 18),
        const Text(
          'Sèvis disponib',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: data.services
              .map(
                (offer) => ServiceButton(
                  offer: offer,
                  onTap: () => _goToService(offer.title),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: () => context.go('/tx/list'),
            icon: const Icon(Icons.receipt_long),
            label: const Text('Lis tranzaksyon mwen'),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Dekonekte'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')), 
      body: _buildBody(),
    );
  }
}
