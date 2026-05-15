import 'package:mon_premye_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../home/presentation/pages/user_home_page.dart';

class AuthGatePage extends StatelessWidget {
  const AuthGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;

    return StreamBuilder<User?>(
      stream: auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;

        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si user konekte -> ale sou Home
        if (user != null) {
          return const UserHomePage();
        }

        // Si user pa konekte -> montre bouton konekte rapid
        return Scaffold(
          appBar: AppBar(title: const Text('Konekte')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ou poko konekte.\nPeze bouton an pou konekte rapid (Anon).',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      await auth.signInAnonymously();
                    },
                    child: const Text('Konekte (Anon)'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

