import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ServiceCatalogPage extends StatefulWidget {
  const ServiceCatalogPage({super.key});

  @override
  State<ServiceCatalogPage> createState() => _ServiceCatalogPageState();
}

class _ServiceCatalogPageState extends State<ServiceCatalogPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final enterpriseCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    bool active = true;

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Create Service'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: enterpriseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enterprise ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Code / Slug',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: active,
                      title: const Text('Active'),
                      onChanged: (v) => setLocal(() => active = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final category = categoryCtrl.text.trim();
                          final enterpriseId = enterpriseCtrl.text.trim();
                          final code = codeCtrl.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Service name pa dwe vid.')),
                            );
                            return;
                          }

                          setLocal(() => saving = true);

                          try {
                            final now = DateTime.now();
                            await FirebaseFirestore.instance.collection('services').add({
                              'name': name,
                              'category': category.isEmpty ? 'general' : category,
                              'enterpriseId': enterpriseId,
                              'code': code,
                              'active': active,
                              'createdAt': Timestamp.fromDate(now),
                              'updatedAt': Timestamp.fromDate(now),
                            });

                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Service created: $name')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setLocal(() => saving = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Erreur create service: $e')),
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

    nameCtrl.dispose();
    categoryCtrl.dispose();
    enterpriseCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _openEditDialog(
    String docId,
    Map<String, dynamic> data,
  ) async {
    final nameCtrl = TextEditingController(text: (data['name'] ?? '').toString());
    final categoryCtrl = TextEditingController(text: (data['category'] ?? '').toString());
    final enterpriseCtrl = TextEditingController(text: (data['enterpriseId'] ?? '').toString());
    final codeCtrl = TextEditingController(text: (data['code'] ?? '').toString());
    bool active = data['active'] is bool ? data['active'] as bool : true;

    await showDialog(
      context: context,
      builder: (context) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Edit Service'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: enterpriseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Enterprise ID',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Code / Slug',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      value: active,
                      title: const Text('Active'),
                      onChanged: (v) => setLocal(() => active = v),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          final category = categoryCtrl.text.trim();
                          final enterpriseId = enterpriseCtrl.text.trim();
                          final code = codeCtrl.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Service name pa dwe vid.')),
                            );
                            return;
                          }

                          setLocal(() => saving = true);

                          try {
                            await FirebaseFirestore.instance
                                .collection('services')
                                .doc(docId)
                                .set({
                              'name': name,
                              'category': category,
                              'enterpriseId': enterpriseId,
                              'code': code,
                              'active': active,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            if (!mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Service updated: $name')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            setLocal(() => saving = false);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(content: Text('Erreur update service: $e')),
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
    categoryCtrl.dispose();
    enterpriseCtrl.dispose();
    codeCtrl.dispose();
  }

  Future<void> _toggleActive({
    required String docId,
    required bool newValue,
    required String name,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('services').doc(docId).set({
        'active': newValue,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newValue ? 'Service aktive: $name' : 'Service dezaktive: $name',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur toggle service: $e')),
      );
    }
  }

  Future<void> _deleteService({
    required String docId,
    required String name,
  }) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete Service'),
              content: Text('Eske ou vle efase service sa a: $name ?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!ok) return;

    try {
      await FirebaseFirestore.instance.collection('services').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Service efase: $name')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur delete service: $e')),
      );
    }
  }

  bool _matchesStatus(bool active) {
    if (_statusFilter == 'all') return true;
    if (_statusFilter == 'active') return active;
    if (_statusFilter == 'inactive') return !active;
    return true;
  }

  Widget _statBox(String title, String value, Color color) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.30)),
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

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Catalog'),
        actions: [
          IconButton(
            tooltip: 'Add Service',
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('New Service'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by name / category / code / enterprise...',
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
                  selected: _statusFilter == 'all',
                  onSelected: (_) => setState(() => _statusFilter = 'all'),
                ),
                ChoiceChip(
                  label: const Text('Active'),
                  selected: _statusFilter == 'active',
                  onSelected: (_) => setState(() => _statusFilter = 'active'),
                ),
                ChoiceChip(
                  label: const Text('Inactive'),
                  selected: _statusFilter == 'inactive',
                  onSelected: (_) => setState(() => _statusFilter = 'inactive'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('services')
                    .orderBy('name')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(child: Text('Erreur services: ${snap.error}'));
                  }

                  final docs = (snap.data?.docs ?? []).where((d) {
                    final m = d.data();
                    final name = (m['name'] ?? '').toString().toLowerCase();
                    final category = (m['category'] ?? '').toString().toLowerCase();
                    final code = (m['code'] ?? '').toString().toLowerCase();
                    final enterpriseId = (m['enterpriseId'] ?? '').toString().toLowerCase();
                    final active = m['active'] is bool ? m['active'] as bool : true;

                    final textOk = query.isEmpty ||
                        name.contains(query) ||
                        category.contains(query) ||
                        code.contains(query) ||
                        enterpriseId.contains(query);

                    return textOk && _matchesStatus(active);
                  }).toList();

                  final total = docs.length;
                  final activeCount = docs.where((d) {
                    final a = d.data()['active'];
                    return a is bool ? a : true;
                  }).length;
                  final inactiveCount = total - activeCount;

                  return ListView(
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _statBox('Services', '$total', Colors.blue),
                          _statBox('Active', '$activeCount', Colors.green),
                          _statBox('Inactive', '$inactiveCount', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (docs.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Pa gen service jwenn.'),
                          ),
                        )
                      else
                        ...docs.map((d) {
                          final m = d.data();
                          final docId = d.id;
                          final name = (m['name'] ?? 'service').toString();
                          final category = (m['category'] ?? '').toString();
                          final code = (m['code'] ?? '').toString();
                          final enterpriseId = (m['enterpriseId'] ?? '').toString();
                          final active = m['active'] is bool ? m['active'] as bool : true;

                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: active
                                    ? Colors.green.withValues(alpha: 0.14)
                                    : Colors.red.withValues(alpha: 0.14),
                                child: Icon(
                                  active ? Icons.check_circle : Icons.block,
                                  color: active ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Text(name),
                              subtitle: Text(
                                'Category: $category\n'
                                'Code: $code\n'
                                'Enterprise: $enterpriseId\n'
                                'Updated: ${_fmtTs(m['updatedAt'])}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openEditDialog(docId, m);
                                  } else if (value == 'toggle') {
                                    _toggleActive(
                                      docId: docId,
                                      newValue: !active,
                                      name: name,
                                    );
                                  } else if (value == 'delete') {
                                    _deleteService(
                                      docId: docId,
                                      name: name,
                                    );
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(active ? 'Disable' : 'Enable'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
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