import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class ManageAgentsPage extends StatefulWidget {
  const ManageAgentsPage({super.key});

  @override
  State<ManageAgentsPage> createState() => _ManageAgentsPageState();
}

class _ManageAgentsPageState extends State<ManageAgentsPage> {
  final _db = FirebaseFirestore.instance;

  Future<void> _openCreateDialog() async {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            bool loading = false;

            Future<void> create() async {
              if (!formKey.currentState!.validate()) return;

              //  Capture navigator + messenger AVAN await
              final nav = Navigator.of(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);

              setDialogState(() => loading = true);

              try {
                final agentId = AppIds.agent(
                  seed: '${emailCtrl.text.trim()}:${DateTime.now()}',
                );
                await _db.collection('agents').doc(agentId).set({
                  'agentId': agentId,
                  'userId': agentId,
                  'email': emailCtrl.text.trim(),
                  'name': nameCtrl.text.trim(),
                  'role': 'agent',
                  'isActive': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                //  Pa itilize context san pwoteksyon
                if (!mounted) return;

                nav.pop(); // fmen dialog la
                messenger.showSnackBar(
                  const SnackBar(content: Text('Agent ajoute!')),
                );
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text('Er: $e')),
                );
              } finally {
                if (mounted) {
                  setDialogState(() => loading = false);
                }
              }
            }

            return AlertDialog(
              title: const Text('Ajoute Agent'),
              content: Form(
                key: formKey,
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Non',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Mete non an' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Mete email la';
                          if (!s.contains('@')) return 'Email pa valid';
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      loading ? null : () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Anile'),
                ),
                ElevatedButton(
                  onPressed: loading ? null : create,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Kreye'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleActive(String docId, bool current) async {
    try {
      await _db.collection('agents').doc(docId).update({'isActive': !current});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(!current ? 'Agent aktive' : 'Agent dezaktive')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Er: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Agents'),
        actions: [
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Ajoute agent',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _db
            .collection('agents')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Er: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
                child: Text('Pa gen ajan ank. Klike + pou ajoute.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final name = (data['name'] ?? '').toString();
              final email = (data['email'] ?? '').toString();
              final isActive = (data['isActive'] ?? true) as bool;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'A'),
                ),
                title: Text(name.isEmpty ? 'Agent' : name),
                subtitle: Text(email),
                trailing: Switch(
                  value: isActive,
                  onChanged: (_) => _toggleActive(d.id, isActive),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
