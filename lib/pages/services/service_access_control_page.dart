import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ServiceAccessControlPage extends StatefulWidget {
  const ServiceAccessControlPage({super.key});

  @override
  State<ServiceAccessControlPage> createState() =>
      _ServiceAccessControlPageState();
}

class _ServiceAccessControlPageState extends State<ServiceAccessControlPage> {
  String? _selectedUserId;
  bool _busy = false;

  String _text(dynamic value, [String fallback = '-']) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  InputDecoration _decor({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF111827), width: 1.3),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadEnterpriseContext() async {
    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception('User pa konekte.');
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.uid)
        .get();

    final userData = userSnap.data() ?? <String, dynamic>{};
    final enterpriseId = (userData['enterpriseId'] ?? '').toString();
    final enterpriseName =
        (userData['enterpriseName'] ?? 'VOUPVAPCASH').toString();

    if (enterpriseId.isEmpty) {
      throw Exception('enterpriseId pa disponib.');
    }

    return {
      'enterpriseId': enterpriseId,
      'enterpriseName': enterpriseName,
      'currentUid': authUser.uid,
    };
  }

  Future<void> _toggleAccess({
    required String enterpriseId,
    required String enterpriseName,
    required Map<String, dynamic> userData,
    required String serviceId,
    required Map<String, dynamic> serviceData,
    required bool nextValue,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final uid = _text(userData['uid'], '');
      if (uid.isEmpty) {
        throw Exception('uid user la pa disponib.');
      }

      final accessId = '${enterpriseId}_${uid}_$serviceId';
      final ref =
          FirebaseFirestore.instance.collection('service_access').doc(accessId);

      if (nextValue) {
        await ref.set({
          'enterpriseId': enterpriseId,
          'enterpriseName': enterpriseName,
          'uid': uid,
          'userDisplayName': _text(userData['displayName']),
          'userEmail': _text(userData['email']),
          'userRole': _text(userData['role']),
          'serviceId': serviceId,
          'serviceName': _text(serviceData['name'], serviceId),
          'serviceCategory': _text(serviceData['category']),
          'isEnabled': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        await ref.delete();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue ? 'Aks Sevis la aktive.' : 'Aks Sevis la retire.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan chanjman aks a: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF111827)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Service Access Control',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadEnterpriseContext(),
        builder: (context, ctxSnap) {
          if (ctxSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ctxSnap.hasError || !ctxSnap.hasData) {
            return Center(
              child: Text('Erreur enterprise: ${ctxSnap.error}'),
            );
          }

          final enterpriseId = ctxSnap.data!['enterpriseId'].toString();
          final enterpriseName = ctxSnap.data!['enterpriseName'].toString();
          final currentUid = ctxSnap.data!['currentUid'].toString();

          final usersStream = FirebaseFirestore.instance
              .collection('users')
              .where('enterpriseId', isEqualTo: enterpriseId)
              .snapshots();

          final servicesStream = FirebaseFirestore.instance
              .collection('services')
              .where('enterpriseId', isEqualTo: enterpriseId)
              .where('active', isEqualTo: true)
              .snapshots();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usersStream,
            builder: (context, userSnap) {
              if (userSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = [...(userSnap.data?.docs ?? [])];
              allUsers.sort((a, b) {
                final an = _text(a.data()['displayName'], '').toLowerCase();
                final bn = _text(b.data()['displayName'], '').toLowerCase();
                return an.compareTo(bn);
              });

              final manageableUsers = allUsers.where((d) {
                final data = d.data();
                final uid = d.id;
                final role = _text(data['role'], '');
                final isActive = data['isActive'] != false;
                if (!isActive) return false;
                if (uid == currentUid) return false;
                if (role == 'owner') return false;
                return true;
              }).toList();

              if (_selectedUserId == null && manageableUsers.isNotEmpty) {
                _selectedUserId = manageableUsers.first.id;
              }

              final selectedUserDoc = manageableUsers
                  .where((e) => e.id == _selectedUserId)
                  .cast<QueryDocumentSnapshot<Map<String, dynamic>>?>()
                  .firstOrNull;

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: servicesStream,
                builder: (context, serviceSnap) {
                  if (serviceSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final serviceDocs = [...(serviceSnap.data?.docs ?? [])];
                  serviceDocs.sort((a, b) {
                    final an = _text(a.data()['name'], '').toLowerCase();
                    final bn = _text(b.data()['name'], '').toLowerCase();
                    return an.compareTo(bn);
                  });

                  final enabledCount = serviceDocs.length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF111827), Color(0xFF1F2937)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.lock_open_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Service Access',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    enterpriseName,
                                    style: const TextStyle(
                                      color: Color(0xFFD1D5DB),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _metricCard(
                            title: 'Users',
                            value: '${manageableUsers.length}',
                            icon: Icons.groups_outlined,
                          ),
                          const SizedBox(width: 10),
                          _metricCard(
                            title: 'Services Aktif',
                            value: '$enabledCount',
                            icon: Icons.miscellaneous_services_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chwazi user',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 14),
                            if (manageableUsers.isEmpty)
                              const Text(
                                  'Pa gen user aktif pou jere aks yo kounye a.')
                            else
                              DropdownButtonFormField<String>(
                                initialValue: _selectedUserId,
                                decoration: _decor(
                                  label: 'User',
                                  icon: Icons.person_outline,
                                ),
                                items: manageableUsers.map((doc) {
                                  final m = doc.data();
                                  final displayName = _text(m['displayName']);
                                  final role = _text(m['role']);
                                  final email = _text(m['email']);
                                  return DropdownMenuItem<String>(
                                    value: doc.id,
                                    child:
                                        Text('$displayName - $role - $email'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedUserId = value;
                                  });
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (manageableUsers.isNotEmpty && selectedUserDoc != null)
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('service_access')
                              .where('enterpriseId', isEqualTo: enterpriseId)
                              .where('uid', isEqualTo: selectedUserDoc.id)
                              .snapshots(),
                          builder: (context, accessSnap) {
                            final accessDocs = accessSnap.data?.docs ?? [];
                            final accessIds = accessDocs
                                .where((d) => d.data()['isEnabled'] == true)
                                .map((d) => _text(d.data()['serviceId'], ''))
                                .where((e) => e.isNotEmpty)
                                .toSet();

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Aks Sevis pou ${_text(selectedUserDoc.data()['displayName'])}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  if (serviceDocs.isEmpty)
                                    const Text(
                                        'Pa gen Sevis aktif pou asiyen kounye a.')
                                  else
                                    ...serviceDocs.map((serviceDoc) {
                                      final serviceId = serviceDoc.id;
                                      final serviceData = serviceDoc.data();
                                      final serviceName =
                                          _text(serviceData['name'], serviceId);
                                      final category =
                                          _text(serviceData['category']);
                                      final isAllowed =
                                          accessIds.contains(serviceId);

                                      return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          border: Border.all(
                                            color: const Color(0xFFE5E7EB),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const CircleAvatar(
                                              backgroundColor:
                                                  Color(0xFFF3F4F6),
                                              child: Icon(
                                                Icons
                                                    .miscellaneous_services_outlined,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    serviceName,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color: Color(0xFF111827),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Kategori: $category',
                                                    style: const TextStyle(
                                                      color: Color(0xFF6B7280),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Switch(
                                              value: isAllowed,
                                              onChanged: _busy
                                                  ? null
                                                  : (value) => _toggleAccess(
                                                        enterpriseId:
                                                            enterpriseId,
                                                        enterpriseName:
                                                            enterpriseName,
                                                        userData: {
                                                          'uid': selectedUserDoc
                                                              .id,
                                                          ...selectedUserDoc
                                                              .data(),
                                                        },
                                                        serviceId: serviceId,
                                                        serviceData:
                                                            serviceData,
                                                        nextValue: value,
                                                      ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 24),
                    ],
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
