import 'package:flutter/material.dart';

class OpenPayoutHistoryPage extends StatelessWidget {
  const OpenPayoutHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Tools'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/payout-history');
          },
          child: const Text('Open Payout History'),
        ),
      ),
    );
  }
}
