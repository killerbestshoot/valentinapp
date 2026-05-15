import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserAccessControlPage extends StatefulWidget {
  const UserAccessControlPage({super.key});

  @override
  State<UserAccessControlPage> createState() => _UserAccessControlPageState();
}

class _UserAccessControlPageState extends State<UserAccessControlPage> {
  final _searchCtrl = TextEditingController();
  String _roleFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _setUserActive({
    required String uid,
    required bool value,
    required String displayName,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'User re-aktive: $displayName'
                : 'User sispann: $displayName',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur user update: $e')),
      );
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.purple;
      case 'administrator':
      case 'admin':
        return Colors.blue;
      case 'agent':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _statBox(String title, String value) {
    return Container(
      width: 160,
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

  bool _matchRole(String role) {
    if (_roleFilter == 'all') return true;
    return role == _roleFilter;
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Access Control'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Chche pa name / email / uid / role...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _roleFilter == 'all',
                  onSelected: (_) => setState(() => _roleFilter = 'all'),
                ),
                ChoiceChip(
                  label: const Text('Owner'),
                  selected: _roleFilter == 'owner',
                  onSelected: (_) => setState(() => _roleFilter = 'owner'),
                ),
                ChoiceChip(
                  label: const Text('Administrator'),
                  selected: _roleFilter == 'administrator',
                  onSelected: (_) => setState(() => _roleFilter = 'administrator'),
                ),
                ChoiceChip(
                  label: const Text('Agent'),
                  selected: _roleFilter == 'agent',
                  onSelected: (_) => setState(() => _roleFilter = 'agent'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(child: Text('Erreur users: ${snap.error}'));
                  }

                  final docs = snap.data?.docs ?? [];

                  final filtered = docs.where((d) {
                    final m = d.data();
                    final uid = d.id.toLowerCase();
                    final displayName =
                        (m['displayName'] ?? m['fullName'] ?? '').toString().toLowerCase();
                    final email = (m['email'] ?? '').toString().toLowerCase();
                    final role = (m['role'] ?? '').toString().toLowerCase();

                    final textMatch = query.isEmpty ||
                        uid.contains(query) ||
                        displayName.contains(query) ||
                        email.contains(query) ||
                        role.contains(query);

                    return textMatch && _matchRole(role);
                  }).toList();

                  final totalUsers = filtered.length;
                  final totalOwners = filtered.where((d) {
                    final r = (d.data()['role'] ?? '').toString().toLowerCase();
                    return r == 'owner';
                  }).length;
                  final totalAdmins = filtered.where((d) {
                    final r = (d.data()['role'] ?? '').toString().toLowerCase();
                    return r == 'administrator' || r == 'admin';
                  }).length;
                  final totalAgents = filtered.where((d) {
                    final r = (d.data()['role'] ?? '').toString().toLowerCase();
                    return r == 'agent';
                  }).length;
                  final totalSuspended = filtered.where((d) {
                    final active = d.data()['isActive'];
                    return active is bool ? !active : false;
                  }).length;

                  if (filtered.isEmpty) {
                    return const Center(child: Text('Pa gen users jwenn.'));
                  }

                  filtered.sort((a, b) {
                    final an = (a.data()['displayName'] ?? a.data()['fullName'] ?? a.id)
                        .toString()
                        .toLowerCase();
                    final bn = (b.data()['displayName'] ?? b.data()['fullName'] ?? b.id)
                        .toString()
                        .toLowerCase();
                    return an.compareTo(bn);
                  });

                  return ListView(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _statBox('Users', '$totalUsers'),
                          _statBox('Owners', '$totalOwners'),
                          _statBox('Admins', '$totalAdmins'),
                          _statBox('Agents', '$totalAgents'),
                          _statBox('Suspended', '$totalSuspended'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...filtered.map((d) {
                        final m = d.data();
                        final uid = d.id;
                        final displayName =
                            (m['displayName'] ?? m['fullName'] ?? 'User').toString();
                        final email = (m['email'] ?? '').toString();
                        final role = (m['role'] ?? '').toString().toLowerCase();
                        final enterpriseId = (m['enterpriseId'] ?? '').toString();
                        final isActive = m['isActive'] is bool ? m['isActive'] as bool : true;

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: _roleColor(role).withOpacity(0.15),
                              child: Icon(
                                role == 'owner'
                                    ? Icons.workspace_premium
                                    : role == 'administrator' || role == 'admin'
                                        ? Icons.admin_panel_settings
                                        : Icons.person,
                                color: _roleColor(role),
                              ),
                            ),
                            title: Text(displayName),
                            subtitle: Text(
                              'Email: $email\n'
                              'UID: $uid\n'
                              'Role: $role | Enterprise: $enterpriseId\n'
                              'Status: ${isActive ? 'active' : 'suspended'}',
                            ),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                if (isActive)
                                  ElevatedButton(
                                    onPressed: () => _setUserActive(
                                      uid: uid,
                                      value: false,
                                      displayName: displayName,
                                    ),
                                    child: const Text('Suspend'),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () => _setUserActive(
                                      uid: uid,
                                      value: true,
                                      displayName: displayName,
                                    ),
                                    child: const Text('Reactivate'),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}