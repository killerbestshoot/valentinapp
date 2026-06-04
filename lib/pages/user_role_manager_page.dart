import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/uuid_v4.dart';
import '../widgets/dashboard_ui.dart';

class UserRoleManagerPage extends StatefulWidget {
  const UserRoleManagerPage({super.key});

  @override
  State<UserRoleManagerPage> createState() => _UserRoleManagerPageState();
}

class _UserRoleManagerPageState extends State<UserRoleManagerPage> {
  final _formKey = GlobalKey<FormState>();

  final _displayNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _saving = false;
  String _selectedRole = 'agent';
  String _search = '';

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardColors.brand, width: 1.3),
      ),
    );
  }

  Future<String> _getEnterpriseId() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('User pa konekte.');
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final userData = userSnap.data() ?? <String, dynamic>{};
    final enterpriseId = (userData['enterpriseId'] ?? '').toString();

    if (enterpriseId.isEmpty) {
      throw Exception('enterpriseId pa disponib.');
    }

    return enterpriseId;
  }

  Future<void> _createUser() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User pa konekte.');
      }

      final enterpriseId = await _getEnterpriseId();

      final currentUserSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final currentUserData = currentUserSnap.data() ?? <String, dynamic>{};
      final enterpriseName =
          (currentUserData['enterpriseName'] ?? 'VOUPVAPCASH').toString();

      final tempApp = FirebaseAuth.instance;

      final cred = await tempApp.createUserWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final newUid = cred.user!.uid;
      final appUserId = UuidV4.generate();

      await FirebaseFirestore.instance.collection('users').doc(newUid).set({
        'uid': newUid,
        'authUid': newUid,
        'userId': appUserId,
        'displayName': _displayNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _selectedRole,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('enterprise_users').add({
        'uid': newUid,
        'authUid': newUid,
        'userId': appUserId,
        'displayName': _displayNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'role': _selectedRole,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: currentUserData['email'].toString(),
        password: '',
      );

      _displayNameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User la kreye avk siks.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan kreyasyon user la: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateRole({
    required String uid,
    required String newRole,
  }) async {
    try {
      final usersQuery = await FirebaseFirestore.instance
          .collection('enterprise_users')
          .where('uid', isEqualTo: uid)
          .get();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'role': newRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final doc in usersQuery.docs) {
        await doc.reference.update({
          'role': newRole,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role la modifye avk siks.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan modifikasyon role la: $e')),
      );
    }
  }

  Future<void> _toggleUser({
    required String uid,
    required bool currentValue,
  }) async {
    try {
      final nextValue = !currentValue;

      final usersQuery = await FirebaseFirestore.instance
          .collection('enterprise_users')
          .where('uid', isEqualTo: uid)
          .get();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'isActive': nextValue,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      for (final doc in usersQuery.docs) {
        await doc.reference.update({
          'isActive': nextValue,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue ? 'User la aktive.' : 'User la dezaktive.',
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

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Users & roles',
      children: [
        const DashboardHero(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Users & roles',
          subtitle: 'Create users, assign roles, and control access.',
        ),
        const SizedBox(height: 18),
        FutureBuilder<String>(
          future: _getEnterpriseId(),
          builder: (context, enterpriseSnap) {
            if (enterpriseSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (enterpriseSnap.hasError || !enterpriseSnap.hasData) {
              return Center(
                child: Text('Erreur enterprise: ${enterpriseSnap.error}'),
              );
            }

            final enterpriseId = enterpriseSnap.data!;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('enterpriseId', isEqualTo: enterpriseId)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = [...(snap.data?.docs ?? [])];
                allDocs.sort((a, b) {
                  final an = _text(a.data()['displayName'], '').toLowerCase();
                  final bn = _text(b.data()['displayName'], '').toLowerCase();
                  return an.compareTo(bn);
                });

                final docs = allDocs.where((d) {
                  final m = d.data();
                  final q = _search.trim().toLowerCase();
                  if (q.isEmpty) return true;
                  return _text(m['displayName'], '')
                          .toLowerCase()
                          .contains(q) ||
                      _text(m['email'], '').toLowerCase().contains(q) ||
                      _text(m['role'], '').toLowerCase().contains(q);
                }).toList();

                final total = allDocs.length;
                final active =
                    allDocs.where((d) => d.data()['isActive'] != false).length;
                final agents = allDocs
                    .where((d) => _text(d.data()['role'], '') == 'agent')
                    .length;
                final admins = allDocs
                    .where(
                        (d) => _text(d.data()['role'], '') == 'administrator')
                    .length;

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: DashboardColors.border),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Ajoute nouvo user',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: DashboardColors.ink,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _displayNameCtrl,
                              decoration: _decor(
                                label: 'Non konpl',
                                icon: Icons.person_outline,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Mete non user la.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decor(
                                label: 'Iml',
                                icon: Icons.email_outlined,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Mete iml la.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: true,
                              decoration: _decor(
                                label: 'Modpas',
                                icon: Icons.lock_outline,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().length < 6) {
                                  return 'Modpas la dwe gen omwen 6 karakt.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRole,
                              decoration: _decor(
                                label: 'Role',
                                icon: Icons.badge_outlined,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'owner',
                                  child: Text('owner'),
                                ),
                                DropdownMenuItem(
                                  value: 'administrator',
                                  child: Text('administrator'),
                                ),
                                DropdownMenuItem(
                                  value: 'agent',
                                  child: Text('agent'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  _selectedRole = value ?? 'agent';
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton.icon(
                                onPressed: _saving ? null : _createUser,
                                icon:
                                    const Icon(Icons.person_add_alt_1_outlined),
                                label: Text(
                                  _saving ? 'Ap kreye...' : 'Ajoute user',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: DashboardColors.border),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.groups_outlined),
                                const SizedBox(height: 8),
                                const Text('Total'),
                                const SizedBox(height: 4),
                                Text(
                                  '$total',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: DashboardColors.border),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.verified_user_outlined),
                                const SizedBox(height: 8),
                                const Text('Aktif'),
                                const SizedBox(height: 4),
                                Text(
                                  '$active',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: DashboardColors.border),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.admin_panel_settings_outlined),
                                const SizedBox(height: 8),
                                const Text('Admins'),
                                const SizedBox(height: 4),
                                Text(
                                  '$admins',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: DashboardColors.border),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.support_agent_outlined),
                                const SizedBox(height: 8),
                                const Text('Agents'),
                                const SizedBox(height: 4),
                                Text(
                                  '$agents',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: _decor(
                        label: 'Chche user',
                        icon: Icons.search,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _search = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (docs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: DashboardColors.border),
                        ),
                        child: const Text('Pa gen user pou montre kounye a.'),
                      )
                    else
                      ...docs.map((d) {
                        final m = d.data();
                        final uid = d.id;
                        final displayName = _text(m['displayName']);
                        final email = _text(m['email']);
                        final role = _text(m['role']);
                        final isActive = m['isActive'] != false;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: DashboardColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFF3F4F6),
                                    child: Icon(
                                      Icons.person_outline,
                                      color: DashboardColors.brand,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          displayName,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: DashboardColors.ink,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email,
                                          style: const TextStyle(
                                            color: DashboardColors.muted,
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
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isActive ? 'Aktif' : 'Inaktif',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: DashboardColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('Role: $role'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: () => _updateRole(
                                      uid: uid,
                                      newRole: 'agent',
                                    ),
                                    child: const Text('Mete agent'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _updateRole(
                                      uid: uid,
                                      newRole: 'administrator',
                                    ),
                                    child: const Text('Mete admin'),
                                  ),
                                  OutlinedButton(
                                    onPressed: () => _updateRole(
                                      uid: uid,
                                      newRole: 'owner',
                                    ),
                                    child: const Text('Mete owner'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isActive
                                          ? Colors.redAccent
                                          : DashboardColors.brand,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _toggleUser(
                                      uid: uid,
                                      currentValue: isActive,
                                    ),
                                    child: Text(
                                      isActive ? 'Dezaktive' : 'Aktive',
                                    ),
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
      ],
    );
  }
}
