import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DevSeedPage extends StatefulWidget {
  const DevSeedPage({super.key});

  @override
  State<DevSeedPage> createState() => _DevSeedPageState();
}

class _DevSeedPageState extends State<DevSeedPage> {
  bool loading = false;

  Future<Map<String, String>> getCurrentUserMeta() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    final data = doc.data();
    if (data == null) {
      throw Exception('User profile not found');
    }

    return {
      'uid': user.uid,
      'role': (data['role'] ?? 'unknown').toString(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
    };
  }

  Future<void> seedDemoData() async {
    try {
      setState(() => loading = true);

      final meta = await getCurrentUserMeta();
      final uid = meta['uid']!;
      final role = meta['role']!;
      final enterpriseId = meta['enterpriseId']!;

      if (role != 'owner' && role != 'administrator') {
        throw Exception('Only owner/administrator can seed demo data');
      }

      if (enterpriseId.isEmpty) {
        throw Exception('No enterprise assigned to this user');
      }

      final now = Timestamp.now();

      final enterpriseRef = FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId);

      await enterpriseRef.set({
        'balance': 2500.0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final payoutRequests = FirebaseFirestore.instance.collection('payout_requests');
      final notifications = FirebaseFirestore.instance.collection('notifications');
      final payoutLogs = FirebaseFirestore.instance.collection('payout_logs');

      final pendingRef = await payoutRequests.add({
        'action': 'pay',
        'uid': uid,
        'enterpriseId': enterpriseId,
        'amount': 75.0,
        'currency': 'USD',
        'status': 'pending',
        'processed': false,
        'paidOut': false,
        'serviceId': 'moncash_ht',
        'serviceName': 'MonCash',
        'createdAt': now,
        'updatedAt': now,
      });

      await payoutRequests.add({
        'action': 'pay',
        'uid': uid,
        'enterpriseId': enterpriseId,
        'amount': 120.0,
        'currency': 'USD',
        'status': 'approved',
        'processed': true,
        'paidOut': true,
        'serviceId': 'natcash_ht',
        'serviceName': 'NatCash',
        'approvedAt': now,
        'approvedBy': uid,
        'approvedByRole': role,
        'balanceBefore': 2500.0,
        'balanceAfter': 2380.0,
        'createdAt': now,
        'updatedAt': now,
      });

      await payoutRequests.add({
        'action': 'pay',
        'uid': uid,
        'enterpriseId': enterpriseId,
        'amount': 40.0,
        'currency': 'USD',
        'status': 'rejected',
        'processed': true,
        'paidOut': false,
        'serviceId': 'laposte_ht',
        'serviceName': 'LaPoste',
        'rejectedAt': now,
        'rejectedBy': uid,
        'rejectedByRole': role,
        'createdAt': now,
        'updatedAt': now,
      });

      await payoutLogs.add({
        'payoutRequestId': pendingRef.id,
        'uid': uid,
        'enterpriseId': enterpriseId,
        'serviceId': 'moncash_ht',
        'serviceName': 'MonCash',
        'amount': 120.0,
        'currency': 'USD',
        'type': 'seed_demo_log',
        'status': 'success',
        'approvedBy': uid,
        'approvedByRole': role,
        'balanceBefore': 2500.0,
        'balanceAfter': 2380.0,
        'createdAt': now,
        'updatedAt': now,
      });

      await notifications.add({
        'type': 'payout_submitted',
        'payoutRequestId': pendingRef.id,
        'uid': uid,
        'enterpriseId': enterpriseId,
        'targetRole': 'administrator',
        'message': 'Demo pending payout created',
        'createdAt': now,
        'read': false,
      });

      await notifications.add({
        'type': 'payout_approved',
        'uid': uid,
        'enterpriseId': enterpriseId,
        'message': 'Demo approved payout created',
        'createdAt': now,
        'read': false,
      });

      await notifications.add({
        'type': 'payout_rejected',
        'uid': uid,
        'enterpriseId': enterpriseId,
        'message': 'Demo rejected payout created',
        'createdAt': now,
        'read': false,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo data seeded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seed error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> clearDemoData() async {
    try {
      setState(() => loading = true);

      final meta = await getCurrentUserMeta();
      final role = meta['role']!;
      final enterpriseId = meta['enterpriseId']!;

      if (role != 'owner' && role != 'administrator') {
        throw Exception('Only owner/administrator can clear demo data');
      }

      if (enterpriseId.isEmpty) {
        throw Exception('No enterprise assigned to this user');
      }

      final batch = FirebaseFirestore.instance.batch();

      final payoutSnap = await FirebaseFirestore.instance
          .collection('payout_requests')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .get();

      for (final doc in payoutSnap.docs) {
        batch.delete(doc.reference);
      }

      final notifSnap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .get();

      for (final doc in notifSnap.docs) {
        batch.delete(doc.reference);
      }

      final logsSnap = await FirebaseFirestore.instance
          .collection('payout_logs')
          .where('enterpriseId', isEqualTo: enterpriseId)
          .get();

      for (final doc in logsSnap.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();

      await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId)
          .set({
        'balance': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo data cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clear error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Widget buildButton({
    required String label,
    required VoidCallback? onPressed,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Seed Tools'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Use this page to seed or clear demo payout data for the current enterprise.',
            ),
            const SizedBox(height: 16),
            buildButton(
              label: loading ? 'Working...' : 'Seed Demo Data',
              onPressed: loading ? null : seedDemoData,
              icon: Icons.playlist_add_check_outlined,
            ),
            const SizedBox(height: 12),
            buildButton(
              label: loading ? 'Working...' : 'Clear Demo Data',
              onPressed: loading ? null : clearDemoData,
              icon: Icons.delete_outline,
            ),
          ],
        ),
      ),
    );
  }
}

