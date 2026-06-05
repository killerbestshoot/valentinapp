import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mon_premye_app/pages/agent/agent_services_dashboard_page.dart';
import 'package:mon_premye_app/pages/payout/payout_hub_page.dart';

class HomeRouter extends StatelessWidget {
  const HomeRouter({super.key});

  Future<String> _getRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final snap = await FirebaseFirestore.instance
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return '';

    return (snap.docs.first.data()['role'] ?? '').toString();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getRole(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = snapshot.data!;

        //  IMPORTANT LOGIC
        if (role == 'agent') {
          return const AgentServicesDashboardPage();
        }

        return const PayoutHubPage();
      },
    );
  }
}
