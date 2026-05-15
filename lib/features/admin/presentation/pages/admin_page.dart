import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('transactions')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('No data'));
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No transactions yet'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final map = (doc.data() as Map<String, dynamic>);
              final type = (map['type'] ?? 'Transaction').toString();

              return Card(
                child: ListTile(
                  title: Text(type),
                  subtitle: const Text('Status: '),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      FirebaseFirestore.instance
                          .collection('transactions')
                          .doc(doc.id)
                          .update({'status': value});
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'paid', child: Text('Mark Paid')),
                      PopupMenuItem(value: 'canceled', child: Text('Cancel')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

