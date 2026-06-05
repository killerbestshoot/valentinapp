import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ManageAgentsScreen extends StatelessWidget {
  const ManageAgentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final col = FirebaseFirestore.instance
        .collection('agents')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Agents')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/admin/create-agent'),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: col.snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('ER: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
                child: Text('Pa gen ajan ank. Peze + pou kreye youn.'));
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i].data();
              final name = (d['name'] ?? '').toString();
              final email = (d['email'] ?? '').toString();
              final active = (d['active'] ?? true) == true;

              return ListTile(
                title: Text(name.isEmpty ? '(No name)' : name),
                subtitle: Text(email),
                trailing: Icon(active ? Icons.check_circle : Icons.block),
              );
            },
          );
        },
      ),
    );
  }
}
