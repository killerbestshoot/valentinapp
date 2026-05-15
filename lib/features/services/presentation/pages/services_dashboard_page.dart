import 'package:flutter/material.dart';

class ServicesDashboardPage extends StatelessWidget {
  const ServicesDashboardPage({super.key});

  static const List<String> services = [
    'Western Union',
    'CAM Transfer',
    'MoneyGram',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services Dashboard'),
      ),
      body: ListView.builder(
        itemCount: services.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(services[index]),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${services[index]} clicked'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

