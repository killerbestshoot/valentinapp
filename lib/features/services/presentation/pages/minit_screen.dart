import 'package:flutter/material.dart';

class MinitScreen extends StatelessWidget {
  const MinitScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minit')),
      body: const Center(child: Text('Modil Minit ap vini...')),
    );
  }
}
