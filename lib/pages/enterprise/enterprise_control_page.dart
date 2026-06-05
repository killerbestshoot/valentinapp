import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EnterpriseControlPage extends StatefulWidget {
  const EnterpriseControlPage({super.key});

  @override
  State<EnterpriseControlPage> createState() => _EnterpriseControlPageState();
}

class _EnterpriseControlPageState extends State<EnterpriseControlPage> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise Control Center'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Chche enterprise pa name oswa id...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('enterprises')
                    .snapshots(),
                builder: (context, enterpriseSnap) {
                  if (enterpriseSnap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (enterpriseSnap.hasError) {
                    return Center(
                      child:
                          Text('Erreur enterprises: ${enterpriseSnap.error}'),
                    );
                  }

                  final enterpriseDocs = enterpriseSnap.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .snapshots(),
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (userSnap.hasError) {
                        return Center(
                          child: Text('Erreur users: ${userSnap.error}'),
                        );
                      }

                      final userDocs = userSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('services')
                            .snapshots(),
                        builder: (context, serviceSnap) {
                          if (serviceSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }

                          if (serviceSnap.hasError) {
                            return Center(
                              child:
                                  Text('Erreur services: ${serviceSnap.error}'),
                            );
                          }

                          final serviceDocs = serviceSnap.data?.docs ?? [];

                          final enterprises = enterpriseDocs.where((d) {
                            final m = d.data();
                            final id = d.id.toLowerCase();
                            final name =
                                (m['name'] ?? m['enterpriseName'] ?? '')
                                    .toString()
                                    .toLowerCase();

                            if (query.isEmpty) return true;
                            return id.contains(query) || name.contains(query);
                          }).toList();

                          if (enterprises.isEmpty) {
                            return const Center(
                              child: Text('Pa gen enterprise jwenn.'),
                            );
                          }

                          return ListView.builder(
                            itemCount: enterprises.length,
                            itemBuilder: (context, index) {
                              final d = enterprises[index];
                              final m = d.data();

                              final enterpriseId = d.id;
                              final enterpriseName = (m['name'] ??
                                      m['enterpriseName'] ??
                                      enterpriseId)
                                  .toString();
                              final balance = _asDouble(m['balance']);

                              final users = userDocs.where((u) {
                                return (u.data()['enterpriseId'] ?? '')
                                        .toString() ==
                                    enterpriseId;
                              }).toList();

                              final totalUsers = users.length;
                              final totalAgents = users.where((u) {
                                return (u.data()['role'] ?? '')
                                        .toString()
                                        .toLowerCase() ==
                                    'agent';
                              }).length;

                              final totalAdmins = users.where((u) {
                                final role = (u.data()['role'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                return role == 'administrator' ||
                                    role == 'admin';
                              }).length;

                              final totalOwners = users.where((u) {
                                return (u.data()['role'] ?? '')
                                        .toString()
                                        .toLowerCase() ==
                                    'owner';
                              }).length;

                              final totalServices = serviceDocs.where((s) {
                                return (s.data()['enterpriseId'] ?? '')
                                        .toString() ==
                                    enterpriseId;
                              }).length;

                              return Card(
                                child: ExpansionTile(
                                  leading: const Icon(Icons.business),
                                  title: Text(enterpriseName),
                                  subtitle: Text(
                                    'ID: $enterpriseId\nBalance: ${balance.toStringAsFixed(2)} USD',
                                  ),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _miniBox('Users', '$totalUsers'),
                                        _miniBox('Agents', '$totalAgents'),
                                        _miniBox('Admins', '$totalAdmins'),
                                        _miniBox('Owners', '$totalOwners'),
                                        _miniBox('Services', '$totalServices'),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Enterprise Summary',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Card(
                                      color: Colors.grey.shade50,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('Name: $enterpriseName'),
                                            Text(
                                                'Enterprise ID: $enterpriseId'),
                                            Text(
                                              'Balance: ${balance.toStringAsFixed(2)} USD',
                                            ),
                                            Text('Users: $totalUsers'),
                                            Text('Agents: $totalAgents'),
                                            Text('Admins: $totalAdmins'),
                                            Text('Owners: $totalOwners'),
                                            Text('Services: $totalServices'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniBox(String title, String value) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
