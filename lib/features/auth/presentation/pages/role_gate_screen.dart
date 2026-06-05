import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleGateScreen extends StatefulWidget {
  const RoleGateScreen({super.key});

  @override
  State<RoleGateScreen> createState() => _RoleGateScreenState();
}

class _RoleGateScreenState extends State<RoleGateScreen> {
  String msg = 'Ap verifye role...';

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final uid = user.uid;

      // 1) check admins/{uid}
      final adminDoc =
          await FirebaseFirestore.instance.collection('admins').doc(uid).get();
      if (adminDoc.exists) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/admin');
        return;
      }

      // 2) check agents/{uid}
      final agentDoc =
          await FirebaseFirestore.instance.collection('agents').doc(uid).get();
      if (agentDoc.exists) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/agent');
        return;
      }

      setState(() => msg =
          'Pa gen role pou user sa a. Seed li km admin oswa kreye li km agent.');
    } catch (e) {
      setState(() => msg = 'ER: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Role Gate')),
      body: Center(
          child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(msg, textAlign: TextAlign.center),
      )),
    );
  }
}
