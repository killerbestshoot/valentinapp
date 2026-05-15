import 'package:flutter/material.dart';

import '../../../../core/routing/app_routes.dart';

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Customer Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.transactions),
                child: const Text('Tranzaksyon mwen yo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

