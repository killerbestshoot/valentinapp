import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AgentsPage extends StatelessWidget {
  const AgentsPage({super.key});

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agents')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'agent')
            .snapshots(),
        builder: (context, usersSnap) {
          if (usersSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (usersSnap.hasError) {
            return Center(child: Text('Erreur users: ${usersSnap.error}'));
          }

          final users = usersSnap.data?.docs ?? [];
          if (users.isEmpty) {
            return const Center(child: Text('Pa gen agent jwenn.'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userDoc = users[index];
              final u = userDoc.data();

              final uid = userDoc.id;
              final name = (u['displayName'] ?? u['fullName'] ?? 'Agent').toString();
              final email = (u['email'] ?? '').toString();
              final enterpriseId = (u['enterpriseId'] ?? '').toString();

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: enterpriseId.isEmpty
                    ? Future.value(null)
                    : FirebaseFirestore.instance
                        .collection('balances')
                        .doc('${enterpriseId}_$uid')
                        .get(),
                builder: (context, balSnap) {
                  final balData = balSnap.data?.data();
                  final balance = _asDouble(balData?['balance']);

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.person),
                      title: Text(name),
                      subtitle: Text('agent | $email\nUID: $uid'),
                      isThreeLine: true,
                      trailing: Text(
                        '${balance.toStringAsFixed(2)} USD',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}