import 'package:flutter/material.dart';

class CashWalletScreen extends StatelessWidget {
  const CashWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cash Wallet')),
      body: const Center(child: Text('CashWalletScreen')),
    );
  }
}
