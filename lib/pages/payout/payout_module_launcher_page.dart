import 'package:flutter/material.dart';

class PayoutModuleLauncherPage extends StatelessWidget {
  const PayoutModuleLauncherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Module'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.pushNamed(context, '/payout-hub');
          },
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: const Text('Open Payout Hub'),
        ),
      ),
    );
  }
}
