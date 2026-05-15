import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../shared/presentation/pages/access_denied_page.dart';

class ClientPortalPage extends StatelessWidget {
  const ClientPortalPage({super.key});

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.can(AppPermission.viewClientPortal)) {
      return const AccessDeniedPage(
        message: 'Se kliyan slman ki ka antre nan espas kliyan an.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espas Kliyan'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .orderBy('createdAt', descending: true)
            .limit(20)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Er pandan chajman done kliyan yo'),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          double totalReceived = 0;

          for (final doc in docs) {
            totalReceived += _toDouble(doc.data()['amount']);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: ListTile(
                  leading: Icon(Icons.person),
                  title: Text('Espas kliyan'),
                  subtitle: Text(
                    'Kliyan se moun k ap resevwa svis sou platfm nan.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Dnye svis ki anrejistre'),
                  trailing: Text(
                    docs.length.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Total montan sou lis la'),
                  trailing: Text(
                    '${totalReceived.toStringAsFixed(2)} HTG',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Sa kliyan an resevwa sou platfm nan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              ...docs.map(
                (doc) {
                  final data = doc.data();
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        (data['service'] ?? 'Svis').toString(),
                      ),
                      subtitle: Text(
                        '${(data['amount'] ?? 0).toString()} HTG\n${(data['country'] ?? '').toString()}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

