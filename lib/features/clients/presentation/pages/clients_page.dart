import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/permissions/app_permission.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../shared/presentation/pages/access_denied_page.dart';
import '../../../transactions/presentation/pages/my_transactions_page.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PermissionService.can(AppPermission.viewClients)) {
      return const AccessDeniedPage(
        message: 'Wl sa pa gen aks ak lis kliyan yo.',
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kliyan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchText = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Chche kliyan...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Er Firestore'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                final Map<String, Map<String, String>> clients = {};

                for (final doc in docs) {
                  final data = doc.data();
                  final phone = (data['phone'] ?? '').toString().trim();
                  if (phone.isEmpty) continue;

                  clients[phone] = {
                    'clientName': (data['clientName'] ?? 'San non').toString(),
                    'phone': phone,
                    'country': (data['country'] ?? '').toString(),
                  };
                }

                final items = clients.values.where((client) {
                  final name = (client['clientName'] ?? '').toLowerCase();
                  final phone = (client['phone'] ?? '').toLowerCase();
                  final country = (client['country'] ?? '').toLowerCase();

                  if (_searchText.isEmpty) return true;
                  return name.contains(_searchText) ||
                      phone.contains(_searchText) ||
                      country.contains(_searchText);
                }).toList();

                if (items.isEmpty) {
                  return const Center(
                    child: Text('Pa gen kliyan toujou'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final client = items[index];
                    final name = client['clientName'] ?? 'San non';
                    final phone = client['phone'] ?? '';
                    final country = client['country'] ?? '';

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '$phone\n$country',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MyTransactionsPage(
                                // // phoneFilter: phone,
                                // // clientName: name,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


