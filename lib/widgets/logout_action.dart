import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.signOut();
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) {
        return route.isFirst;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ou dekonekte.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Logout',
      icon: const Icon(Icons.logout),
      onPressed: () => _logout(context),
    );
  }
}
