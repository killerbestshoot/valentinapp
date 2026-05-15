import 'package:flutter/material.dart';

class OpenPayoutApprovalPage extends StatelessWidget {
  const OpenPayoutApprovalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Tools'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/payout-approvals');
          },
          child: const Text('Open Payout Approvals'),
        ),
      ),
    );
  }
}

