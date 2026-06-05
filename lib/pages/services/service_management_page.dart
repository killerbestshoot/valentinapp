import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class ServiceManagementPage extends StatefulWidget {
  const ServiceManagementPage({super.key});

  @override
  State<ServiceManagementPage> createState() => _ServiceManagementPageState();
}

class _ServiceManagementPageState extends State<ServiceManagementPage> {
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _search = '';
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String _text(dynamic value, [String fallback = '-']) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Future<String?> _enterpriseId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final data = snap.data() ?? <String, dynamic>{};
    final enterpriseId = (data['enterpriseId'] ?? '').toString().trim();
    return enterpriseId.isEmpty ? null : enterpriseId;
  }

  Future<void> _addService() async {
    if (_saving) return;

    final name = _nameCtrl.text.trim();
    final category = _categoryCtrl.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete non Sevis la.')),
      );
      return;
    }

    if (category.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete kategori Sevis la.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final enterpriseId = await _enterpriseId();
      if (enterpriseId == null) {
        throw Exception('enterpriseId pa disponib.');
      }

      final serviceId = AppIds.service(seed: '$enterpriseId:$category:$name');

      await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .set({
        'serviceId': serviceId,
        'enterpriseId': enterpriseId,
        'name': name,
        'category': category,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _nameCtrl.clear();
      _categoryCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sevis la ajoute avk siks.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan ajoute Sevis la: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleService({
    required String docId,
    required bool currentValue,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(docId)
          .update({
        'active': !currentValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentValue
                ? 'Sevis la aktif kounye a.'
                : 'Sevis la dezaktive kounye a.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan chanjman status la: $e')),
      );
    }
  }

  Future<void> _deleteService(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('services')
          .doc(docId)
          .delete();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sevis la efase.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan efasman Sevis la: $e')),
      );
    }
  }

  Future<void> _editService({
    required String docId,
    required String currentName,
    required String currentCategory,
  }) async {
    final nameCtrl = TextEditingController(text: currentName);
    final categoryCtrl = TextEditingController(text: currentCategory);

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Modifye Sevis'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Non Sevis',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anile'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final category = categoryCtrl.text.trim();

                if (name.isEmpty || category.isEmpty) {
                  return;
                }

                await FirebaseFirestore.instance
                    .collection('services')
                    .doc(docId)
                    .update({
                  'name': name,
                  'category': category,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                if (context.mounted) {
                  Navigator.pop(context);
                }

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sevis la modifye.')),
                );
              },
              child: const Text('Sove'),
            ),
          ],
        );
      },
    );

    nameCtrl.dispose();
    categoryCtrl.dispose();
  }

  Widget _statCard({
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
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
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
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Services Management')),
        body: const Center(
          child: Text('User pa konekte.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Services Management',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(authUser.uid)
            .get(),
        builder: (context, userSnap) {
          if (userSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userSnap.hasError) {
            return Center(
              child: Text('Erreur user: ${userSnap.error}'),
            );
          }

          final userData = userSnap.data?.data() ?? <String, dynamic>{};
          final enterpriseId =
              (userData['enterpriseId'] ?? '').toString().trim();

          if (enterpriseId.isEmpty) {
            return const Center(
              child: Text('enterpriseId pa disponib.'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('services')
                .where('enterpriseId', isEqualTo: enterpriseId)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snap.hasError) {
                return Center(
                  child: Text('Erreur services: ${snap.error}'),
                );
              }

              final allDocs = [...(snap.data?.docs ?? [])];

              allDocs.sort((a, b) {
                final an = _text(a.data()['name'], '').toLowerCase();
                final bn = _text(b.data()['name'], '').toLowerCase();
                return an.compareTo(bn);
              });

              final docs = allDocs.where((d) {
                if (_search.trim().isEmpty) return true;
                final m = d.data();
                final haystack = [
                  _text(m['name'], ''),
                  _text(m['category'], ''),
                ].join(' ').toLowerCase();
                return haystack.contains(_search.trim().toLowerCase());
              }).toList();

              int activeCount = 0;
              int inactiveCount = 0;

              for (final d in allDocs) {
                final isActive = d.data()['active'] == true;
                if (isActive) {
                  activeCount++;
                } else {
                  inactiveCount++;
                }
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
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
                          'Ajoute nouvo Sevis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _nameCtrl,
                          decoration: InputDecoration(
                            labelText: 'Non Sevis',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _categoryCtrl,
                          decoration: InputDecoration(
                            labelText: 'Kategori',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: _saving ? null : _addService,
                            icon: const Icon(Icons.add_circle_outline),
                            label: Text(
                              _saving ? 'Ap sove...' : 'Ajoute Sevis',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _statCard(
                        title: 'Total',
                        value: allDocs.length.toString(),
                        icon: Icons.miscellaneous_services_outlined,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        title: 'Aktif',
                        value: activeCount.toString(),
                        icon: Icons.check_circle_outline,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard(
                        title: 'Inaktif',
                        value: inactiveCount.toString(),
                        icon: Icons.pause_circle_outline,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        title: 'Rezilta',
                        value: docs.length.toString(),
                        icon: Icons.search_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      setState(() {
                        _search = v;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Chche pa non oswa kategori...',
                      prefixIcon: const Icon(Icons.search),
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
                        borderSide: const BorderSide(
                          color: Color(0xFF111827),
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (docs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Text('Pa gen Sevis pou montre kounye a.'),
                    )
                  else
                    ...docs.map((d) {
                      final m = d.data();
                      final docId = d.id;
                      final name = _text(m['name']);
                      final category = _text(m['category']);
                      final isActive = m['active'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(
                                  backgroundColor: Color(0xFFF3F4F6),
                                  child: Icon(
                                    Icons.miscellaneous_services_outlined,
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
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
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
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? const Color(0xFFD1FAE5)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    isActive ? 'Aktif' : 'Inaktif',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _editService(
                                    docId: docId,
                                    currentName: name == '-' ? '' : name,
                                    currentCategory:
                                        category == '-' ? '' : category,
                                  ),
                                  child: const Text('Modifye'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _toggleService(
                                    docId: docId,
                                    currentValue: isActive,
                                  ),
                                  child: Text(
                                    isActive ? 'Dezaktive' : 'Aktive',
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _deleteService(docId),
                                  child: const Text('Efase'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
