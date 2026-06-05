import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class CreateAgentScreen extends StatefulWidget {
  const CreateAgentScreen({super.key});

  @override
  State<CreateAgentScreen> createState() => _CreateAgentScreenState();
}

class _CreateAgentScreenState extends State<CreateAgentScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController(text: '123456');

  bool loading = false;
  String msg = '';

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _createAgent() async {
    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => msg = 'Ranpli non + email + modpas');
      return;
    }

    setState(() {
      loading = true;
      msg = '';
    });

    final adminAuth = FirebaseAuth.instance;
    final adminUser = adminAuth.currentUser;

    if (adminUser == null) {
      setState(() {
        loading = false;
        msg = 'Ou pa konekte km admin.';
      });
      return;
    }

    try {
      // IMPORTANT: createUserWithEmailAndPassword changes the current user
      // So we store admin email and ask admin to re-login after creating agent.
      final adminEmail = adminUser.email;

      final cred = await adminAuth.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final uid = cred.user!.uid;
      final agentId = AppIds.agent(seed: uid);

      await FirebaseFirestore.instance.collection('agents').doc(uid).set({
        'uid': uid,
        'agentId': agentId,
        'userId': agentId,
        'name': name,
        'email': email,
        'role': 'agent',
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': adminEmail ?? 'admin',
      });

      setState(() => msg = 'OK  Ajan kreye: $email');

      // Sign out agent user we just created
      await adminAuth.signOut();

      // Go back to login (admin re-login)
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } catch (e) {
      setState(() => msg = 'ER: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Agent')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Non Ajan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email Ajan'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Modpas Ajan'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : _createAgent,
              child: Text(loading ? 'Ap kreye...' : 'KREYE AJAN'),
            ),
            const SizedBox(height: 12),
            Text(msg),
            const SizedBox(height: 12),
            const Text(
              "Nt: Apre ou kreye ajan, app la ap dekonekte pou sekirite. Re-login km admin.",
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
