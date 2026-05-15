import 'package:flutter/material.dart';

class NewTransactionScreen extends StatelessWidget {
  final String? initialService;

  const NewTransactionScreen({
    super.key,
    this.initialService,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Transaction'),
      ),
      body: Center(
        child: Text(
          initialService == null
              ? 'NewTransactionScreen placeholder'
              : 'NewTransactionScreen placeholder\nService: $initialService',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

