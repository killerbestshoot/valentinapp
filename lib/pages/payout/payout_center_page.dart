import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class PayoutCenterPage extends StatefulWidget {
  const PayoutCenterPage({super.key});

  @override
  State<PayoutCenterPage> createState() => _PayoutCenterPageState();
}

class _PayoutCenterPageState extends State<PayoutCenterPage> {
  final _amountCtrl = TextEditingController();
  final _serviceNameCtrl = TextEditingController();
  final _serviceIdCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _filter = 'all';
  bool _saving = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _serviceNameCtrl.dispose();
    _serviceIdCtrl.dispose();
    _noteCtrl.dispose();
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

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Future<Map<String, dynamic>> _loadCurrentUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw Exception('User pa connecte.');
    }

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    return {
      'uid': uid,
      'displayName':
          (data['displayName'] ?? data['fullName'] ?? 'Staff').toString(),
      'role': (data['role'] ?? 'agent').toString().toLowerCase(),
      'enterpriseId': (data['enterpriseId'] ?? '').toString(),
      'enterpriseName': (data['enterpriseName'] ?? 'VOUPVAPCASH').toString(),
    };
  }

  Future<void> _createPayoutRequest() async {
    if (_saving) return;

    final amount = _asDouble(_amountCtrl.text.trim());
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete yon amount valid.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final user = await _loadCurrentUser();
      final requestId = AppIds.payoutRequest(
        seed: '${user['enterpriseId']}:${user['uid']}:${DateTime.now()}',
      );

      await FirebaseFirestore.instance
          .collection('payout_requests')
          .doc(requestId)
          .set({
        'requestId': requestId,
        'payoutId': requestId,
        'uid': user['uid'],
        'displayName': user['displayName'],
        'role': user['role'],
        'enterpriseId': user['enterpriseId'],
        'enterpriseName': user['enterpriseName'],
        'serviceId': _serviceIdCtrl.text.trim(),
        'serviceName': _serviceNameCtrl.text.trim(),
        'amount': amount,
        'currency': 'USD',
        'note': _noteCtrl.text.trim(),
        'status': 'pending',
        'processed': false,
        'paidOut': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _amountCtrl.clear();
      _serviceNameCtrl.clear();
      _serviceIdCtrl.clear();
      _noteCtrl.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout request created ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur create payout: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _approvePayout({
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    try {
      final currentUser = await _loadCurrentUser();
      final currentRole = (currentUser['role'] ?? '').toString();

      if (currentRole != 'owner' &&
          currentRole != 'administrator' &&
          currentRole != 'admin') {
        throw Exception('Se owner/admin slman ki ka approve payout.');
      }

      final enterpriseId = (data['enterpriseId'] ?? '').toString();
      final amount = _asDouble(data['amount']);
      final requesterUid = (data['uid'] ?? '').toString();
      final serviceId = (data['serviceId'] ?? '').toString();
      final serviceName = (data['serviceName'] ?? '').toString();

      final payoutRef =
          FirebaseFirestore.instance.collection('payout_requests').doc(docId);
      final enterpriseRef = FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final payoutSnap = await tx.get(payoutRef);
        if (!payoutSnap.exists) {
          throw Exception('Payout request pa egziste.');
        }

        final payoutData = payoutSnap.data() ?? <String, dynamic>{};
        if ((payoutData['processed'] ?? false) == true) {
          throw Exception('Payout sa deja trete.');
        }

        final enterpriseSnap = await tx.get(enterpriseRef);
        final enterpriseData = enterpriseSnap.data() ?? <String, dynamic>{};

        final balanceBefore = _asDouble(enterpriseData['balance']);
        if (balanceBefore < amount) {
          throw Exception('Enterprise balance pa sifi.');
        }

        final balanceAfter = balanceBefore - amount;

        tx.set(
            enterpriseRef,
            {
              'balance': balanceAfter,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        tx.set(
            payoutRef,
            {
              'status': 'approved',
              'processed': true,
              'paidOut': true,
              'approvedAt': FieldValue.serverTimestamp(),
              'approvedBy': currentUser['uid'],
              'approvedByRole': currentRole,
              'balanceBefore': balanceBefore,
              'balanceAfter': balanceAfter,
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));

        final logId = AppIds.payoutLog(seed: 'payout_center:$docId');
        final logRef =
            FirebaseFirestore.instance.collection('payout_logs').doc(logId);
        tx.set(logRef, {
          'logId': logId,
          'payoutRequestId': docId,
          'uid': requesterUid,
          'enterpriseId': enterpriseId,
          'serviceId': serviceId,
          'serviceName': serviceName,
          'amount': amount,
          'currency': (payoutData['currency'] ?? 'USD').toString(),
          'type': 'payout_approved',
          'approvedBy': currentUser['uid'],
          'approvedByRole': currentRole,
          'balanceBefore': balanceBefore,
          'balanceAfter': balanceAfter,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout approved ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur approve payout: $e')),
      );
    }
  }

  Future<void> _rejectPayout({
    required String docId,
  }) async {
    try {
      final currentUser = await _loadCurrentUser();
      final currentRole = (currentUser['role'] ?? '').toString();

      if (currentRole != 'owner' &&
          currentRole != 'administrator' &&
          currentRole != 'admin') {
        throw Exception('Se owner/admin slman ki ka reject payout.');
      }

      await FirebaseFirestore.instance
          .collection('payout_requests')
          .doc(docId)
          .set({
        'status': 'rejected',
        'processed': true,
        'paidOut': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': currentUser['uid'],
        'rejectedByRole': currentRole,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout rejected ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur reject payout: $e')),
      );
    }
  }

  bool _matchFilter(String status) {
    if (_filter == 'all') return true;
    return status.toLowerCase() == _filter;
  }

  Widget _statBox(String title, String value, Color color) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center),
          const SizedBox(height: 4),
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
    return FutureBuilder<Map<String, dynamic>>(
      future: _loadCurrentUser(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payout Center PRO')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (userSnap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Payout Center PRO')),
            body: Center(child: Text('Erreur user: ${userSnap.error}')),
          );
        }

        final user = userSnap.data ?? <String, dynamic>{};
        final currentRole = (user['role'] ?? '').toString();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Payout Center PRO'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text(
                          'CREATE PAYOUT REQUEST',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _serviceIdCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Service ID',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _serviceNameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Service Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount USD',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _noteCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _createPayoutRequest,
                            icon: const Icon(Icons.payments_outlined),
                            label: Text(_saving
                                ? 'Saving...'
                                : 'Create Payout Request'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    ChoiceChip(
                      label: const Text('Pending'),
                      selected: _filter == 'pending',
                      onSelected: (_) => setState(() => _filter = 'pending'),
                    ),
                    ChoiceChip(
                      label: const Text('Approved'),
                      selected: _filter == 'approved',
                      onSelected: (_) => setState(() => _filter = 'approved'),
                    ),
                    ChoiceChip(
                      label: const Text('Rejected'),
                      selected: _filter == 'rejected',
                      onSelected: (_) => setState(() => _filter = 'rejected'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('payout_requests')
                        .orderBy('createdAt', descending: true)
                        .limit(300)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snap.hasError) {
                        return Center(
                            child:
                                Text('Erreur payout requests: ${snap.error}'));
                      }

                      final docs = (snap.data?.docs ?? []).where((d) {
                        final status = (d.data()['status'] ?? '').toString();
                        return _matchFilter(status);
                      }).toList();

                      int pendingCount = 0;
                      int approvedCount = 0;
                      int rejectedCount = 0;
                      double pendingTotal = 0;
                      double approvedTotal = 0;

                      for (final d in docs) {
                        final m = d.data();
                        final status =
                            (m['status'] ?? '').toString().toLowerCase();
                        final amount = _asDouble(m['amount']);

                        if (status == 'pending') {
                          pendingCount++;
                          pendingTotal += amount;
                        } else if (status == 'approved') {
                          approvedCount++;
                          approvedTotal += amount;
                        } else if (status == 'rejected') {
                          rejectedCount++;
                        }
                      }

                      return ListView(
                        children: [
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _statBox(
                                  'Pending', '$pendingCount', Colors.orange),
                              _statBox(
                                  'Approved', '$approvedCount', Colors.green),
                              _statBox(
                                  'Rejected', '$rejectedCount', Colors.red),
                              _statBox(
                                  'Pending Total',
                                  '${pendingTotal.toStringAsFixed(2)} USD',
                                  Colors.blue),
                              _statBox(
                                  'Approved Total',
                                  '${approvedTotal.toStringAsFixed(2)} USD',
                                  Colors.purple),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (docs.isEmpty)
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Pa gen payout requests jwenn.'),
                              ),
                            )
                          else
                            ...docs.map((d) {
                              final m = d.data();
                              final status = (m['status'] ?? '').toString();
                              final amount = _asDouble(m['amount']);
                              final serviceName =
                                  (m['serviceName'] ?? '').toString();
                              final serviceId =
                                  (m['serviceId'] ?? '').toString();
                              final enterpriseId =
                                  (m['enterpriseId'] ?? '').toString();
                              final uid = (m['uid'] ?? '').toString();
                              final displayName =
                                  (m['displayName'] ?? '').toString();
                              final note = (m['note'] ?? '').toString();
                              final processed = m['processed'] == true;

                              return Card(
                                child: ExpansionTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _statusColor(status)
                                        .withValues(alpha: 0.14),
                                    child: Icon(
                                      Icons.payments_outlined,
                                      color: _statusColor(status),
                                    ),
                                  ),
                                  title:
                                      Text('${amount.toStringAsFixed(2)} USD'),
                                  subtitle: Text(
                                    'Status: $status\n'
                                    'Service: $serviceName | Enterprise: $enterpriseId',
                                  ),
                                  childrenPadding:
                                      const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'UID: $uid\n'
                                        'Display Name: $displayName\n'
                                        'Service ID: $serviceId\n'
                                        'Created: ${_fmtTs(m['createdAt'])}\n'
                                        'Updated: ${_fmtTs(m['updatedAt'])}\n'
                                        'Balance Before: ${_asDouble(m['balanceBefore']).toStringAsFixed(2)}\n'
                                        'Balance After: ${_asDouble(m['balanceAfter']).toStringAsFixed(2)}\n'
                                        'Note: ${note.isEmpty ? "-" : note}',
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    if (!processed &&
                                        (currentRole == 'owner' ||
                                            currentRole == 'administrator' ||
                                            currentRole == 'admin'))
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => _approvePayout(
                                              docId: d.id,
                                              data: m,
                                            ),
                                            child: const Text('Approve'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => _rejectPayout(
                                              docId: d.id,
                                            ),
                                            child: const Text('Reject'),
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
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
