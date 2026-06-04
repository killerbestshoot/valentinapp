import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'owner_dashboard.dart';
import 'pages/agent_dashboard.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'services/user_profile_service.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _GateLoading();
        }

        final user = authSnap.data;
        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<UserProfile>(
          future: UserProfileService.instance.ensureProfileForUser(user: user),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _GateLoading();
            }

            if (profileSnap.hasError) {
              return _GateError(message: 'Erreur profil: ${profileSnap.error}');
            }

            final profile = profileSnap.data;
            if (profile == null) {
              return const _GateError(message: 'Profil user pa disponib.');
            }

            if (!profile.isActive) {
              return _InactiveUser(profile: profile);
            }

            if (profile.isOwner) {
              return OwnerDashboard(
                enterpriseId: profile.enterpriseId,
                enterpriseName: profile.enterpriseName,
                displayName: profile.displayName,
                email: profile.email,
                userId: profile.userId,
              );
            }

            if (profile.isAdmin) {
              return const AdminDashboard();
            }

            if (profile.isAgent) {
              return const AgentDashboard();
            }

            return const HomePage();
          },
        );
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _GateError extends StatelessWidget {
  const _GateError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _InactiveUser extends StatelessWidget {
  const _InactiveUser({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.block_outlined, size: 44),
              const SizedBox(height: 16),
              Text(
                'Kont sa dezaktive.',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${profile.displayName}\n${profile.email}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => FirebaseAuth.instance.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Retounen sou login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
