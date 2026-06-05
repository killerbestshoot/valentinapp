import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('VOUPVAPCASH')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Byenvini',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 46,
              child: ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('Konekte'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 220,
              height: 46,
              child: OutlinedButton(
                onPressed: () => context.go('/register'),
                child: const Text('Kreye kont ajan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
