import 'package:flutter/material.dart';

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("User Home"),
      ),
      body: const Center(
        child: Text(
          "Welcome to VOUPVAPCASH",
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
