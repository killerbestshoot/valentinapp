import 'package:flutter/material.dart';

class ServicesDashboardScreen extends StatelessWidget {
  const ServicesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services Dashboard')),
      body: ListView(
        children: const [
          ListTile(
            title: Text('Western Union'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(height: 1),
          ListTile(
            title: Text('CAM Transfer'),
            trailing: Icon(Icons.chevron_right),
          ),
          Divider(height: 1),
          ListTile(
            title: Text('MoneyGram'),
            trailing: Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

