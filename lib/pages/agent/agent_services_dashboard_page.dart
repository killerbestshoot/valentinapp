import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_premye_app/pages/transactions/dynamic_transaction_page.dart';

class AgentServicesDashboardPage extends StatelessWidget {
  const AgentServicesDashboardPage({super.key});

  Future<Map<String, dynamic>> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(user.uid).get();

    final entSnap = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (entSnap.docs.isEmpty) {
      throw Exception('Enterprise pa jwenn');
    }

    final ent = entSnap.docs.first.data();

    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': (userDoc.data()?['displayName'] ?? '').toString(),
      'role': (ent['role'] ?? '').toString(),
      'enterpriseId': (ent['enterpriseId'] ?? '').toString(),
      'enterpriseName': (ent['enterpriseName'] ?? '').toString(),
      'isActive': (ent['isActive'] ?? false),
    };
  }

  Future<Map<String, dynamic>> _loadServicesWithFallback(
      String enterpriseId) async {
    final db = FirebaseFirestore.instance;

    final enterpriseQuery = await db
        .collection('services')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .where('active', isEqualTo: true)
        .get();

    if (enterpriseQuery.docs.isNotEmpty) {
      return {
        'mode': 'enterprise',
        'docs': enterpriseQuery.docs,
      };
    }

    final globalQuery =
        await db.collection('services').where('active', isEqualTo: true).get();

    return {
      'mode': 'global',
      'docs': globalQuery.docs,
    };
  }

  Widget _serviceCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final name = (data['name'] ?? '').toString();
    final category = (data['category'] ?? '').toString();
    final country = (data['country'] ?? '').toString();
    final serviceEnterpriseId = (data['enterpriseId'] ?? '').toString();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DynamicTransactionPage(
              serviceId: doc.id,
              serviceData: data,
            ),
          ),
        );
      },
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.apps, size: 40),
              const SizedBox(height: 10),
              Text(
                name.isEmpty ? 'SERVICE' : name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              if (country.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  country,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                serviceEnterpriseId,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Services Dashboard'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadProfile(),
        builder: (context, profileSnap) {
          if (profileSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ER PROFILE: ${profileSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!profileSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = profileSnap.data!;
          final enterpriseId = (profile['enterpriseId'] ?? '').toString();

          return FutureBuilder<Map<String, dynamic>>(
            future: _loadServicesWithFallback(enterpriseId),
            builder: (context, serviceSnap) {
              if (serviceSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER SERVICES: ${serviceSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!serviceSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final mode =
                  (serviceSnap.data!['mode'] ?? 'enterprise').toString();
              final docs = (serviceSnap.data!['docs'] as List)
                  .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();

              return Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.teal.shade50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (profile['enterpriseName'] ?? '').toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                            'Agent: ${(profile['displayName'] ?? '').toString()}'),
                        Text('Role: ${(profile['role'] ?? '').toString()}'),
                        Text('EnterpriseId: $enterpriseId'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: mode == 'enterprise'
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            mode == 'enterprise'
                                ? 'ENTERPRISE MATCH'
                                : 'GLOBAL FALLBACK',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: mode == 'enterprise'
                                  ? Colors.green.shade900
                                  : Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(
                            child: Text(
                                'Pa gen svis disponib menm nan fallback la'),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.15,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              return _serviceCard(context, docs[index]);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
