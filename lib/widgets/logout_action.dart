import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/auth_repository_provider.dart';

class LogoutAction extends StatelessWidget {
  const LogoutAction({super.key});

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    await AuthRepositoryProvider.instance.signOut();

    if (context.mounted) {
      router.go('/login');
      messenger.showSnackBar(
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
