import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'routing/app_routes.dart';

class SessionGuard extends StatelessWidget {
  const SessionGuard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final user = snap.data;

        // Pa konekte -> Welcome
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushNamedAndRemoveUntil(
                context, AppRoutes.welcome, (_) => false);
          });
          return const SizedBox.shrink();
        }

        // Konekte -> voye li sou Customer (default)
        // (Apre sa ou ka mete RoleGate/SessionGuard avanse)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushNamedAndRemoveUntil(
              context, AppRoutes.customer, (_) => false);
        });

        return const SizedBox.shrink();
      },
    );
  }
}

