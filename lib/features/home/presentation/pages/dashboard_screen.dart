import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      context.go('/');
    }
  }

  void _goNewTx(BuildContext context, String service) {
    final s = Uri.encodeComponent(service);
    context.go('/tx/new?service=$s');
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    Widget serviceBtn(String title, IconData icon) {
      return SizedBox(
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => _goNewTx(context, title),
          icon: Icon(icon),
          label: Text(title),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Dekonekte',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Ou konekte',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Email: ${user?.email ?? "-"}'),
          const SizedBox(height: 16),
          const Text(
            'Svis yo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: serviceBtn(
                  'MonCash',
                  Icons.account_balance_wallet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: serviceBtn(
                  'NatCash',
                  Icons.payments,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: serviceBtn(
                  'Western Union',
                  Icons.public,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: serviceBtn(
                  'CAM Transf',
                  Icons.swap_horiz,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/tx/list'),
              icon: const Icon(Icons.receipt_long),
              label: const Text('Lis Tranzaksyon mwen'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => context.go('/countries'),
              icon: const Icon(Icons.flag),
              label: const Text('Lis Peyi (kd telefn)'),
            ),
          ),
        ],
      ),
    );
  }
}

