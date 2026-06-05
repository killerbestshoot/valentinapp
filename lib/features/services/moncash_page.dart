import 'package:flutter/material.dart';

class MonCashPage extends StatelessWidget {
  const MonCashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MonCash'),
      ),
      body: const Center(
        child: Text(
          'Paj MonCash la mache ',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
