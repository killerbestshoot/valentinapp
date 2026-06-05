import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class WalletTopupPage extends StatefulWidget {
  const WalletTopupPage({super.key});

  @override
  State<WalletTopupPage> createState() => _WalletTopupPageState();
}

class _WalletTopupPageState extends State<WalletTopupPage> {
  final _searchCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _loading = false;

  Future<Map<String, dynamic>> _getOwnerProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User pa konekte');

    final entSnap = await FirebaseFirestore.instance
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (entSnap.docs.isEmpty) {
      throw Exception('enterprise_users pa jwenn');
    }

    final ent = entSnap.docs.first.data();
    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'enterpriseId': (ent['enterpriseId'] ?? '').toString(),
      'enterpriseName': (ent['enterpriseName'] ?? '').toString(),
      'role': (ent['role'] ?? '').toString().toLowerCase(),
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _staffStream(
      String enterpriseId) {
    return FirebaseFirestore.instance
        .collection('enterprise_users')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Future<void> _submitTopup({
    required Map<String, dynamic> owner,
    required Map<String, dynamic> staff,
  }) async {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete yon amount ki valid')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final requestId = AppIds.topupRequest(
        seed:
            '${owner['enterpriseId']}:${staff['uid']}:${DateTime.now().toIso8601String()}',
      );

      await FirebaseFirestore.instance
          .collection('wallet_topup_requests')
          .doc(requestId)
          .set({
        'requestId': requestId,
        'topupId': requestId,
        'enterpriseId': owner['enterpriseId'],
        'enterpriseName': owner['enterpriseName'],
        'ownerUid': owner['uid'],
        'ownerEmail': owner['email'],
        'targetUid': (staff['uid'] ?? '').toString(),
        'targetName': (staff['displayName'] ?? '').toString(),
        'targetEmail': (staff['email'] ?? '').toString(),
        'targetRole': (staff['role'] ?? '').toString(),
        'amount': amount,
        'currency': 'USD',
        'status': 'pending',
        'approved': false,
        'rejected': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _amountCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Topup request voye avk siks')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER TOPUP: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matches(Map<String, dynamic> data, String q) {
    final s = q.toLowerCase().trim();
    if (s.isEmpty) return true;
    final name = (data['displayName'] ?? '').toString().toLowerCase();
    final email = (data['email'] ?? '').toString().toLowerCase();
    final uid = (data['uid'] ?? '').toString().toLowerCase();
    return name.contains(s) || email.contains(s) || uid.contains(s);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getOwnerProfile(),
      builder: (context, profileSnap) {
        if (profileSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Wallet Topup')),
            body: Center(
              child: Text(
                'ER PROFILE: ${profileSnap.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!profileSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final owner = profileSnap.data!;
        final enterpriseId = owner['enterpriseId'].toString();

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _staffStream(enterpriseId),
          builder: (context, staffSnap) {
            if (staffSnap.hasError) {
              return Scaffold(
                appBar: AppBar(title: const Text('Wallet Topup')),
                body: Center(
                  child: Text(
                    'ER STAFFS: ${staffSnap.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!staffSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final q = _searchCtrl.text.trim();
            final docs = staffSnap.data!.docs.map((e) => e.data()).where((e) {
              final uid = (e['uid'] ?? '').toString();
              final role = (e['role'] ?? '').toString().toLowerCase();
              if (uid == owner['uid'].toString()) return false;
              if (role == 'owner') return false;
              return _matches(e, q);
            }).toList();

            return Scaffold(
              appBar: AppBar(title: const Text('Wallet Topup')),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ROLE: ${owner['role']}'),
                              Text('ENTERPRISE: ${owner['enterpriseName']}'),
                              Text('ENTERPRISE ID: ${owner['enterpriseId']}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Chche staff pa email / uid / non',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          hintText: 'Amount topup (ex: 100)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_loading) const LinearProgressIndicator(),
                      const SizedBox(height: 10),
                      if (docs.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(18),
                            child:
                                Text('Pa gen staff ki koresponn ak rechch la'),
                          ),
                        ),
                      ...docs.map((staff) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (staff['displayName'] ?? '').toString(),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                    'Email: ${(staff['email'] ?? '').toString()}'),
                                Text('UID: ${(staff['uid'] ?? '').toString()}'),
                                Text(
                                    'Role: ${(staff['role'] ?? '').toString()}'),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loading
                                        ? null
                                        : () => _submitTopup(
                                            owner: owner, staff: staff),
                                    child: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 14),
                                      child: Text('Voye topup request la'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
