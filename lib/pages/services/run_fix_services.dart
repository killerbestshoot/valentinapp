import 'package:flutter/material.dart';
import 'package:mon_premye_app/scripts/fix_services.dart';

class RunFixServicesPage extends StatelessWidget {
  const RunFixServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fix Services")),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await fixServices();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Service fixed ")),
            );
          },
          child: const Text("RUN FIX"),
        ),
      ),
    );
  }
}
