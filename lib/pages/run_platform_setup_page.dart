import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RunPlatformSetupPage extends StatefulWidget {
  const RunPlatformSetupPage({super.key});

  @override
  State<RunPlatformSetupPage> createState() => _RunPlatformSetupPageState();
}

class _RunPlatformSetupPageState extends State<RunPlatformSetupPage> {
  bool _busy = false;

  static const String ownerUid = 'METE_VRE_OWNER_UID_LA';
  static const String adminUid = 'METE_VRE_ADMIN_UID_LA';
  static const String agentUid = 'METE_VRE_AGENT_UID_LA';

  static const String enterpriseId = 'ENT-001';
  static const String enterpriseName = 'VOUPVAPCASH';

  static const String ownerName = 'Owner';
  static const String adminName = 'Administrator';
  static const String agentName = 'Agent';

  static const String ownerEmail = 'owner@test.com';
  static const String adminEmail = 'admin@test.com';
  static const String agentEmail = 'agent@test.com';

  Future<void> _runSetup() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final fs = FirebaseFirestore.instance;

      await fs.collection('enterprises').doc(enterpriseId).set({
        'enterpriseId': enterpriseId,
        'name': enterpriseName,
        'active': true,
        'balance': 1000.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final users = [
        {
          'uid': ownerUid,
          'displayName': ownerName,
          'fullName': ownerName,
          'email': ownerEmail,
          'role': 'owner',
          'enterpriseId': enterpriseId,
          'enterpriseName': enterpriseName,
          'isActive': true,
        },
        {
          'uid': adminUid,
          'displayName': adminName,
          'fullName': adminName,
          'email': adminEmail,
          'role': 'administrator',
          'enterpriseId': enterpriseId,
          'enterpriseName': enterpriseName,
          'isActive': true,
        },
        {
          'uid': agentUid,
          'displayName': agentName,
          'fullName': agentName,
          'email': agentEmail,
          'role': 'agent',
          'enterpriseId': enterpriseId,
          'enterpriseName': enterpriseName,
          'isActive': true,
        },
      ];

      for (final u in users) {
        final uid = u['uid']!.toString();

        await fs.collection('users').doc(uid).set({
          'uid': uid,
          'displayName': u['displayName'],
          'fullName': u['fullName'],
          'email': u['email'],
          'role': u['role'],
          'enterpriseId': u['enterpriseId'],
          'enterpriseName': u['enterpriseName'],
          'isActive': u['isActive'],
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await fs.collection('enterprise_users').doc('${enterpriseId}_$uid').set({
          'enterpriseUserId': '${enterpriseId}_$uid',
          'enterpriseId': enterpriseId,
          'uid': uid,
          'displayName': u['displayName'],
          'email': u['email'],
          'role': u['role'],
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await fs.collection('balances').doc('${enterpriseId}_OWNER').set({
        'enterpriseId': enterpriseId,
        'uid': ownerUid,
        'role': 'owner',
        'balance': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await fs.collection('balances').doc('${enterpriseId}_$agentUid').set({
        'enterpriseId': enterpriseId,
        'uid': agentUid,
        'role': 'agent',
        'balance': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final services = [
        {
          'id': 'moncash_ht',
          'name': 'MonCash',
          'category': 'wallet',
          'country': 'HT',
          'code': 'MONCASH',
          'active': true,
        },
        {
          'id': 'natcash_ht',
          'name': 'NatCash',
          'category': 'wallet',
          'country': 'HT',
          'code': 'NATCASH',
          'active': true,
        },
        {
          'id': 'minutes_topup',
          'name': 'Send Minutes',
          'category': 'topup',
          'country': 'HT',
          'code': 'MINIT',
          'active': true,
        },
      ];

      for (final s in services) {
        await fs.collection('services').doc(s['id']!.toString()).set({
          'name': s['name'],
          'category': s['category'],
          'country': s['country'],
          'code': s['code'],
          'enterpriseId': enterpriseId,
          'active': s['active'],
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final allowed = <String>{'moncash_ht', 'natcash_ht', 'minutes_topup'};
      final allServices = await fs.collection('services').get();

      for (final d in allServices.docs) {
        await d.reference.set({
          'enterpriseId': enterpriseId,
          'active': allowed.contains(d.id),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final rows = [
        {'uid': ownerUid, 'role': 'owner'},
        {'uid': adminUid, 'role': 'administrator'},
        {'uid': agentUid, 'role': 'agent'},
      ];

      for (final row in rows) {
        for (final serviceId in allowed) {
          final accessId = '${enterpriseId}_${row['uid']}_$serviceId';
          await fs.collection('service_access').doc(accessId).set({
            'accessId': accessId,
            'enterpriseId': enterpriseId,
            'uid': row['uid'],
            'role': row['role'],
            'serviceId': serviceId,
            'allowed': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Platform setup fini  owner/admin/agent pare.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur platform setup: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Setup'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Peze bouton an yon sl fwa pou mete owner, administrator, agent, enterprise, balances, service access, ak 3 services yo an plas.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Enterprise', '$enterpriseName ($enterpriseId)'),
                    _row('Owner UID', ownerUid),
                    _row('Admin UID', adminUid),
                    _row('Agent UID', agentUid),
                    _row('Owner role', 'owner'),
                    _row('Admin role', 'administrator'),
                    _row('Agent role', 'agent'),
                    _row('Services', 'moncash_ht / natcash_ht / minutes_topup'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _busy ? null : _runSetup,
              icon: const Icon(Icons.play_arrow),
              label: Text(_busy ? 'Processing...' : 'RUN PLATFORM SETUP'),
            ),
          ],
        ),
      ),
    );
  }
}