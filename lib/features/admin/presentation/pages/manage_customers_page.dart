import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageCustomersPage extends StatelessWidget {
  const ManageCustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final users = FirebaseFirestore.instance.collection('users');

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Customers')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: users.where('role', isEqualTo: 'customer').snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Pa gen customer ank.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              return ListTile(
                title: Text(d['email']?.toString() ?? ''),
                subtitle: Text('role: ${d['role'] ?? 'customer'}'),
              );
            },
          );
        },
      ),
    );
  }
}

