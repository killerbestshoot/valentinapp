import 'package:flutter/material.dart';

class OpenPayoutDashboardPage extends StatelessWidget {
  const OpenPayoutDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Tools'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/payout-dashboard');
          },
          child: const Text('Open Payout Dashboard'),
        ),
      ),
    );
  }
}

