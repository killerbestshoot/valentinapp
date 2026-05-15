import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EnterpriseControlCenterPage extends StatefulWidget {
  const EnterpriseControlCenterPage({super.key});

  @override
  State<EnterpriseControlCenterPage> createState() =>
      _EnterpriseControlCenterPageState();
}

class _EnterpriseControlCenterPageState
    extends State<EnterpriseControlCenterPage> {
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

  String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd $hh:$mi';
    }
    return '-';
  }

  Future<void> _openCreateDialog() async {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool active = true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return AlertDialog(
              title: const Text('Create Enterprise'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: idCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enterprise ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enterprise Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: active,
                      onChanged: saving
                          ? null
                          : (v) => setLocal(() => active = v),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final enterpriseId = idCtrl.text.trim();
                          final name = nameCtrl.text.trim();
                          final note = noteCtrl.text.trim();

                          if (enterpriseId.isEmpty || name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enterprise ID ak Name obligatwa.'),
                              ),
                            );
                            return;
                          }

                          setLocal(() => saving = true);

                          try {
                            await FirebaseFirestore.instance
                                .collection('enterprises')
                                .doc(enterpriseId)
                                .set({
                              'enterpriseId': enterpriseId,
                              'name': name,
                              'note': note,
                              'active': active,
                              'balance': 0,
                              'createdAt': FieldValue.serverTimestamp(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Enterprise created: $enterpriseId'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setLocal(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur create enterprise: $e'),
                              ),
                            );
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Create'),
                ),
              ],
            );
          },
        );
      },
    );

    idCtrl.dispose();
    nameCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _openEditDialog(
    String enterpriseId,
    Map<String, dynamic> data,
  ) async {
    final nameCtrl = TextEditingController(
      text: (data['name'] ?? '').toString(),
    );
    final noteCtrl = TextEditingController(
      text: (data['note'] ?? '').toString(),
    );
    bool active = data['active'] is bool ? data['active'] as bool : true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setLocal) {
            return AlertDialog(
              title: const Text('Edit Enterprise'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Enterprise ID',
                        border: const OutlineInputBorder(),
                        hintText: enterpriseId,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enterprise Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: active,
                      onChanged: saving
                          ? null
                          : (v) => setLocal(() => active = v),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final note = noteCtrl.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enterprise name obligatwa.'),
                              ),
                            );
                            return;
                          }

                          setLocal(() => saving = true);

                          try {
                            await FirebaseFirestore.instance
                                .collection('enterprises')
                                .doc(enterpriseId)
                                .set({
                              'name': name,
                              'note': note,
                              'active': active,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (!mounted) return;
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Enterprise updated: $enterpriseId'),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setLocal(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Erreur update enterprise: $e'),
                              ),
                            );
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    noteCtrl.dispose();
  }

  Future<void> _toggleEnterprise(
    String enterpriseId,
    bool newValue,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId)
          .set({
        'active': newValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue
                ? 'Enterprise aktive: $enterpriseId'
                : 'Enterprise dezaktive: $enterpriseId',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur toggle enterprise: $e')),
      );
    }
  }

  Widget _statBox(String title, String value, Color color) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enterprise Control Center PRO'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business),
            tooltip: 'Create Enterprise',
            onPressed: _openCreateDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Enterprise'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by enterpriseId / name / note...',
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
                builder: (context, entSnap) {
                  if (entSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (entSnap.hasError) {
                    return Center(child: Text('Erreur enterprises: ${entSnap.error}'));
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance.collection('users').snapshots(),
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (userSnap.hasError) {
                        return Center(child: Text('Erreur users: ${userSnap.error}'));
                      }

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('balances').snapshots(),
                        builder: (context, balSnap) {
                          if (balSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (balSnap.hasError) {
                            return Center(child: Text('Erreur balances: ${balSnap.error}'));
                          }

                          final entDocs = entSnap.data?.docs ?? [];
                          final userDocs = userSnap.data?.docs ?? [];
                          final balDocs = balSnap.data?.docs ?? [];

                          final filtered = entDocs.where((d) {
                            final m = d.data();
                            final id = (m['enterpriseId'] ?? d.id).toString().toLowerCase();
                            final name = (m['name'] ?? '').toString().toLowerCase();
                            final note = (m['note'] ?? '').toString().toLowerCase();

                            if (query.isEmpty) return true;
                            return id.contains(query) ||
                                name.contains(query) ||
                                note.contains(query);
                          }).toList();

                          filtered.sort((a, b) {
                            final an = (a.data()['name'] ?? a.id).toString().toLowerCase();
                            final bn = (b.data()['name'] ?? b.id).toString().toLowerCase();
                            return an.compareTo(bn);
                          });

                          int activeCount = 0;
                          int inactiveCount = 0;
                          double totalBusinessBalance = 0;

                          final List<Map<String, dynamic>> rows = [];

                          for (final d in filtered) {
                            final m = d.data();
                            final enterpriseId =
                                (m['enterpriseId'] ?? d.id).toString();
                            final active =
                                m['active'] is bool ? m['active'] as bool : true;

                            if (active) {
                              activeCount++;
                            } else {
                              inactiveCount++;
                            }

                            int ownerCount = 0;
                            int adminCount = 0;
                            int agentCount = 0;
                            int clientCount = 0;

                            for (final u in userDocs) {
                              final um = u.data();
                              final uidEnterprise =
                                  (um['enterpriseId'] ?? '').toString();
                              if (uidEnterprise != enterpriseId) continue;

                              final role =
                                  (um['role'] ?? '').toString().toLowerCase();

                              if (role == 'owner') {
                                ownerCount++;
                              } else if (role == 'administrator' || role == 'admin') {
                                adminCount++;
                              } else if (role == 'agent') {
                                agentCount++;
                              } else if (role == 'client') {
                                clientCount++;
                              }
                            }

                            double enterpriseBalance = 0;
                            for (final b in balDocs) {
                              final bm = b.data();
                              final balEnterprise =
                                  (bm['enterpriseId'] ?? '').toString();
                              if (balEnterprise != enterpriseId) continue;
                              enterpriseBalance += _asDouble(bm['balance']);
                            }

                            totalBusinessBalance += enterpriseBalance;

                            rows.add({
                              'docId': d.id,
                              'enterpriseId': enterpriseId,
                              'name': (m['name'] ?? '').toString(),
                              'note': (m['note'] ?? '').toString(),
                              'active': active,
                              'balance': enterpriseBalance,
                              'ownerCount': ownerCount,
                              'adminCount': adminCount,
                              'agentCount': agentCount,
                              'clientCount': clientCount,
                              'updatedAt': m['updatedAt'],
                            });
                          }

                          if (rows.isEmpty) {
                            return ListView(
                              children: [
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _statBox('Enterprises', '0', Colors.blue),
                                    _statBox('Active', '$activeCount', Colors.green),
                                    _statBox('Inactive', '$inactiveCount', Colors.red),
                                    _statBox(
                                      'Business Balance',
                                      '${totalBusinessBalance.toStringAsFixed(2)} USD',
                                      Colors.purple,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text('Pa gen enterprise jwenn.'),
                                  ),
                                ),
                              ],
                            );
                          }

                          return ListView(
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _statBox('Enterprises', '${rows.length}', Colors.blue),
                                  _statBox('Active', '$activeCount', Colors.green),
                                  _statBox('Inactive', '$inactiveCount', Colors.red),
                                  _statBox(
                                    'Business Balance',
                                    '${totalBusinessBalance.toStringAsFixed(2)} USD',
                                    Colors.purple,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...rows.map((row) {
                                final active = row['active'] as bool;
                                final color = active ? Colors.green : Colors.red;

                                return Card(
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: color.withValues(alpha: 0.14),
                                      child: Icon(
                                        active ? Icons.business : Icons.block,
                                        color: color,
                                      ),
                                    ),
                                    title: Text(
                                      '${row['name']} (${row['enterpriseId']})',
                                    ),
                                    subtitle: Text(
                                      'Balance: ${(row['balance'] as double).toStringAsFixed(2)} USD\n'
                                      'Status: ${active ? 'active' : 'inactive'}',
                                    ),
                                    childrenPadding:
                                        const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                    children: [
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Owner: ${row['ownerCount']}\n'
                                          'Admin: ${row['adminCount']}\n'
                                          'Agent: ${row['agentCount']}\n'
                                          'Client: ${row['clientCount']}\n'
                                          'Updated: ${_fmtTs(row['updatedAt'])}\n'
                                          'Note: ${row['note'].toString().isEmpty ? '-' : row['note']}',
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _openEditDialog(
                                              row['enterpriseId'].toString(),
                                              {
                                                'name': row['name'],
                                                'note': row['note'],
                                                'active': row['active'],
                                              },
                                            ),
                                            child: const Text('Edit'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => _toggleEnterprise(
                                              row['enterpriseId'].toString(),
                                              !active,
                                            ),
                                            child: Text(
                                              active ? 'Deactivate' : 'Activate',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
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
}