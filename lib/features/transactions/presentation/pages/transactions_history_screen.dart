import 'package:flutter/material.dart';

class TransactionsHistoryScreen extends StatelessWidget {
  const TransactionsHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions History')),
      body: const Center(child: Text('TransactionsHistoryScreen')),
    );
  }
}

