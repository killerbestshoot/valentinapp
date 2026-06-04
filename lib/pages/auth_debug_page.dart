import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/dashboard_ui.dart';

class AuthDebugPage extends StatelessWidget {
  const AuthDebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DashboardPage(
      title: 'Auth Debug',
      children: [
        const DashboardHero(
          icon: Icons.verified_user_outlined,
          title: 'Auth diagnostics',
          subtitle: 'Inspect the current session and linked user profile.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user == null ? 'PA GEN USER KONEKTE' : 'USER KONEKTE',
                style: const TextStyle(
                  color: DashboardColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              _DebugLine(label: 'uid', value: user?.uid ?? ''),
              _DebugLine(label: 'email', value: user?.email ?? ''),
              _DebugLine(
                label: 'displayName',
                value: user?.displayName ?? '',
              ),
              _DebugLine(
                label: 'isAnonymous',
                value: '${user?.isAnonymous ?? ''}',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (user != null)
          FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, snap) {
              final data = snap.data?.data();

              return DashboardPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const DashboardSectionTitle(
                      title: 'USER DOC users/{currentUid}',
                    ),
                    const SizedBox(height: 12),
                    if (snap.connectionState == ConnectionState.waiting)
                      const CircularProgressIndicator()
                    else if (snap.hasError)
                      Text('Er: ${snap.error}')
                    else if (data == null)
                      const Text('Doc sa a pa egziste.')
                    else ...[
                      _DebugLine(label: 'uid', value: '${data['uid'] ?? '-'}'),
                      _DebugLine(
                          label: 'role', value: '${data['role'] ?? '-'}'),
                      _DebugLine(
                        label: 'email',
                        value: '${data['email'] ?? '-'}',
                      ),
                      _DebugLine(
                        label: 'displayName',
                        value:
                            '${data['displayName'] ?? data['fullName'] ?? '-'}',
                      ),
                      _DebugLine(
                        label: 'enterpriseId',
                        value: '${data['enterpriseId'] ?? '-'}',
                      ),
                      _DebugLine(
                        label: 'enterpriseName',
                        value: '${data['enterpriseName'] ?? '-'}',
                      ),
                      _DebugLine(
                        label: 'isActive',
                        value: '${data['isActive'] ?? '-'}',
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DebugLine extends StatelessWidget {
  const _DebugLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: DashboardColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: DashboardColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
