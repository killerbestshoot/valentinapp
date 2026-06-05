import 'package:flutter/material.dart';
import 'package:mon_premye_app/scripts/seed_services.dart';

class RunSeedServicesPage extends StatelessWidget {
  const RunSeedServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seed Services')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            await seedServices();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Services normalized ')),
            );
          },
          child: const Text('RUN SEED'),
        ),
      ),
    );
  }
}
