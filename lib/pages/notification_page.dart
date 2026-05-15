import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NotificationPage extends StatelessWidget {
  final String enterpriseId;

  const NotificationPage({super.key, required this.enterpriseId});

  String _date(dynamic v) {
    if (v is! Timestamp) return '-';
    final d = v.toDate();
    return "${d.year}-${d.month}-${d.day} ${d.hour}:${d.minute}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Notifications")),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = [...snap.data!.docs];

          docs.sort((a, b) {
            final da = a.data()['createdAt'];
            final db = b.data()['createdAt'];
            if (da is Timestamp && db is Timestamp) {
              return db.toDate().compareTo(da.toDate());
            }
            return 0;
          });

          if (docs.isEmpty) {
            return const Center(child: Text("Pa gen notification."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final m = docs[i].data();

              return ListTile(
                title: Text(m['title'] ?? ''),
                subtitle: Text(m['message'] ?? ''),
                trailing: Text(_date(m['createdAt'])),
              );
            },
          );
        },
      ),
    );
  }
}