import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleGatePage extends StatelessWidget {
  final List<String> allowedRoles;
  final Widget child;
  final String deniedMessage;

  const RoleGatePage({
    super.key,
    required this.allowedRoles,
    required this.child,
    required this.deniedMessage,
  });

  Future<Map<String, String>> getCurrentUserMeta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data();
    if (data == null) {
      throw Exception('User profile not found');
    }

    return {
      'uid': user.uid,
      'role': (data['role'] ?? 'unknown').toString(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, String>>(
      future: getCurrentUserMeta(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Check'),
            ),
            body: Center(
              child: Text('Error: ${snapshot.error}'),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final role = snapshot.data?['role'] ?? '';

        if (!allowedRoles.contains(role)) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Denied'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  deniedMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
