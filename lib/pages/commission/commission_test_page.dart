import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CommissionTestPage extends StatefulWidget {
  const CommissionTestPage({super.key});

  @override
  State<CommissionTestPage> createState() => _CommissionTestPageState();
}

class _CommissionTestPageState extends State<CommissionTestPage> {
  bool loading = false;

  Future<String> _getRole(String uid) async {
    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? '').toString().trim();
      if (role.isNotEmpty) return role;
    }

    final q = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      return (q.docs.first.data()['role'] ?? 'agent').toString().trim();
    }

    return 'agent';
  }

  Future<void> addTestTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User pa konekte')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final db = FirebaseFirestore.instance;
      final role = await _getRole(user.uid);

      await db.collection('transactions').doc('TXN_TEST_003').set({
        'txId': 'TXN_TEST_003',
        'enterpriseId': 'ENT-001',
        'enterpriseName': 'VOUPVAPCASH',
        'staffUid': user.uid,
        'staffName': (user.email ?? 'test user'),
        'staffRole': role,
        'serviceId': 'SRV_MONCASH',
        'serviceName': 'MonCash',
        'category': 'transfer',
        'status': 'delivered',
        'paymentStatus': 'paid',
        'paymentAmount': 100,
        'paymentCurrency': 'USD',
        'transferAmount': 100,
        'transferCurrency': 'USD',
        'commissionAgent': 10,
        'commissionOwner': 2,
        'commissionApplied': false,
        'customerName': 'TEST CUSTOMER',
        'customerPhone': '0000000000',
        'beneficiaryName': 'TEST BENEFICIARY',
        'beneficiaryPhone': '0000000000',
        'reference': 'TEST-REF-003',
        'notes': 'Commission test transaction',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Test transaction added: TXN_TEST_003')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Er: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Commission Test'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: loading ? null : addTestTransaction,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Text(
                loading ? 'Tanpri tann...' : 'Add Test Transaction 100 USD'),
          ),
        ),
      ),
    );
  }
}
