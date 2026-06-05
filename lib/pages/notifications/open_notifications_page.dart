import 'package:flutter/material.dart';

class OpenNotificationsPage extends StatelessWidget {
  const OpenNotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications Entry'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/notifications');
          },
          child: const Text('Open Notifications'),
        ),
      ),
    );
  }
}
