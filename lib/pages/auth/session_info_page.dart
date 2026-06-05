import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SessionInfoPage extends StatelessWidget {
  const SessionInfoPage({super.key});

  Future<Map<String, String>> getCurrentUserMeta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = doc.data() ?? {};

    return {
      'uid': user.uid,
      'email': (user.email ?? '').toString(),
      'role': (data['role'] ?? 'unknown').toString(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
    };
  }

  Widget buildRow(String label, String value) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(value.isEmpty ? '-' : value),
      ),
    );
  }

  Future<void> signOut(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign out error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Info'),
      ),
      body: FutureBuilder<Map<String, String>>(
        future: getCurrentUserMeta(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final data = snapshot.data ?? {};

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              buildRow('UID', data['uid'] ?? ''),
              buildRow('Email', data['email'] ?? ''),
              buildRow('Role', data['role'] ?? ''),
              buildRow('Enterprise ID', data['enterpriseId'] ?? ''),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          );
        },
      ),
    );
  }
}
