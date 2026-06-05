import 'package:flutter/material.dart';

class AccessDeniedPage extends StatelessWidget {
  final String title;
  final String message;

  const AccessDeniedPage({
    super.key,
    this.title = 'Aks entdi',
    this.message = 'Ou pa gen dwa pou antre nan pati sa.',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock, size: 64),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retounen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
