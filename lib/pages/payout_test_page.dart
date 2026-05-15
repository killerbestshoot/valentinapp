import 'package:flutter/material.dart';
import '../widgets/payout_button.dart';

class PayoutTestPage extends StatelessWidget {
  const PayoutTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await submitPayoutRequest(
              context: context,
              amount: 10,
              enterpriseId: 'ENT-001',
              serviceId: 'manual_test',
              serviceName: 'Manual Test',
            );
          },
          child: const Text('TEST PAYOUT REQUEST'),
        ),
      ),
    );
  }
}
