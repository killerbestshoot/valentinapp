import 'package:flutter/material.dart';

class OpenPayoutAdminHubPage extends StatelessWidget {
  const OpenPayoutAdminHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Entry'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/payout-hub');
          },
          child: const Text('Open Payout Admin Hub'),
        ),
      ),
    );
  }
}

