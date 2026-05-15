import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PayoutApprovalPage extends StatefulWidget {
  const PayoutApprovalPage({super.key});

  @override
  State<PayoutApprovalPage> createState() => _PayoutApprovalPageState();
}

class _PayoutApprovalPageState extends State<PayoutApprovalPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();

  bool _busy = false;
  String _historyFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
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

  String _mainTab() => _tabController.index == 0 ? 'pending' : 'history';

  bool _matchesSearch(Map<String, dynamic> m, String docId) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;

    final txId = (m['txId'] ?? '').toString().toLowerCase();
    final uid = (m['uid'] ?? '').toString().toLowerCase();
    final serviceName = (m['serviceName'] ?? '').toString().toLowerCase();
    final enterpriseId = (m['enterpriseId'] ?? '').toString().toLowerCase();
    final status = (m['status'] ?? '').toString().toLowerCase();
    final type = (m['type'] ?? '').toString().toLowerCase();
    final id = docId.toLowerCase();

    return txId.contains(q) ||
        uid.contains(q) ||
        serviceName.contains(q) ||
        enterpriseId.contains(q) ||
        status.contains(q) ||
        type.contains(q) ||
        id.contains(q);
  }

  bool _matchesMainTab(Map<String, dynamic> m) {
    final status = (m['status'] ?? '').toString().toLowerCase();
    final tab = _mainTab();

    if (tab == 'pending') {
      return status == 'pending';
    }

    if (_historyFilter == 'approved') return status == 'approved';
    if (_historyFilter == 'rejected') return status == 'rejected';
    return status == 'approved' || status == 'rejected';
  }

  Widget _statBox(String title, String value, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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

  Future<void> _approveRequest(
    String docId,
    Map<String, dynamic> requestData,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User pa connect.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final approverRole =
          (userDoc.data()?['role'] ?? 'administrator').toString();

      final reqRef =
          FirebaseFirestore.instance.collection('payout_requests').doc(docId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) {
          throw Exception('Payout request pa jwenn.');
        }

        final req = reqSnap.data() as Map<String, dynamic>;
        final status = (req['status'] ?? '').toString().toLowerCase();
        final processed = req['processed'] == true;

        if (processed || status != 'pending') {
          throw Exception('Request sa deja trete.');
        }

        final enterpriseId = (req['enterpriseId'] ?? '').toString();
        if (enterpriseId.isEmpty) {
          throw Exception('enterpriseId pa disponib.');
        }

        final amount = _asDouble(req['amount']);
        final entRef =
            FirebaseFirestore.instance.collection('enterprises').doc(enterpriseId);
        final entSnap = await tx.get(entRef);

        if (!entSnap.exists) {
          throw Exception('Enterprise pa jwenn.');
        }

        final entData = entSnap.data() as Map<String, dynamic>;
        final balanceBefore = _asDouble(entData['balance']);

        if (balanceBefore < amount) {
          throw Exception('Enterprise balance pa sifi.');
        }

        final balanceAfter = balanceBefore - amount;

        tx.set(
          entRef,
          {
            'balance': balanceAfter,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.set(
          reqRef,
          {
            'status': 'approved',
            'processed': true,
            'paidOut': true,
            'approvedAt': FieldValue.serverTimestamp(),
            'approvedBy': currentUser.uid,
            'approvedByRole': approverRole,
            'balanceBefore': balanceBefore,
            'balanceAfter': balanceAfter,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        final logRef =
            FirebaseFirestore.instance.collection('payout_logs').doc();

        tx.set(logRef, {
          'payoutRequestId': docId,
          'uid': req['uid'],
          'enterpriseId': enterpriseId,
          'serviceId': req['serviceId'],
          'serviceName': req['serviceName'],
          'amount': amount,
          'currency': (req['currency'] ?? 'USD').toString(),
          'type': 'payout_approved',
          'approvedBy': currentUser.uid,
          'approvedByRole': approverRole,
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
        SnackBar(content: Text('Erreur approve: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _rejectRequest(
    String docId,
    Map<String, dynamic> requestData,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User pa connect.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final approverRole =
          (userDoc.data()?['role'] ?? 'administrator').toString();

      final reqRef =
          FirebaseFirestore.instance.collection('payout_requests').doc(docId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final reqSnap = await tx.get(reqRef);
        if (!reqSnap.exists) {
          throw Exception('Payout request pa jwenn.');
        }

        final req = reqSnap.data() as Map<String, dynamic>;
        final status = (req['status'] ?? '').toString().toLowerCase();
        final processed = req['processed'] == true;

        if (processed || status != 'pending') {
          throw Exception('Request sa deja trete.');
        }

        tx.set(
          reqRef,
          {
            'status': 'rejected',
            'processed': true,
            'paidOut': false,
            'rejectedAt': FieldValue.serverTimestamp(),
            'rejectedBy': currentUser.uid,
            'rejectedByRole': approverRole,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        final logRef =
            FirebaseFirestore.instance.collection('payout_logs').doc();

        tx.set(logRef, {
          'payoutRequestId': docId,
          'uid': req['uid'],
          'enterpriseId': req['enterpriseId'],
          'serviceId': req['serviceId'],
          'serviceName': req['serviceName'],
          'amount': _asDouble(req['amount']),
          'currency': (req['currency'] ?? 'USD').toString(),
          'type': 'payout_rejected',
          'rejectedBy': currentUser.uid,
          'rejectedByRole': approverRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout rejected ')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur reject: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Color _statusColor(String status) {
    switch (status) {
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

  Widget _buildRequestCard(String docId, Map<String, dynamic> m) {
    final amount = _asDouble(m['amount']);
    final status = (m['status'] ?? 'pending').toString().toLowerCase();
    final serviceName = (m['serviceName'] ?? '').toString();
    final enterpriseId = (m['enterpriseId'] ?? '').toString();
    final uid = (m['uid'] ?? '').toString();
    final type = (m['type'] ?? '').toString();
    final currency = (m['currency'] ?? 'USD').toString();

    final createdAt = _fmtTs(m['createdAt']);
    final approvedAt = _fmtTs(m['approvedAt']);
    final rejectedAt = _fmtTs(m['rejectedAt']);

    final statusColor = _statusColor(status);

    return Card(
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.14),
          child: Icon(
            status == 'approved'
                ? Icons.check_circle
                : status == 'rejected'
                    ? Icons.cancel
                    : Icons.hourglass_bottom,
            color: statusColor,
          ),
        ),
        title: Text('${amount.toStringAsFixed(2)} $currency'),
        subtitle: Text(
          'Status: $status | Service: ${serviceName.isEmpty ? "-" : serviceName}\n'
          'Enterprise: ${enterpriseId.isEmpty ? "-" : enterpriseId}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Doc ID: $docId\n'
              'UID: $uid\n'
              'Type: ${type.isEmpty ? "-" : type}\n'
              'Created: $createdAt\n'
              'Approved: $approvedAt\n'
              'Rejected: $rejectedAt\n'
              'Processed: ${(m['processed'] == true)}\n'
              'PaidOut: ${(m['paidOut'] == true)}\n'
              'Balance Before: ${_asDouble(m['balanceBefore']).toStringAsFixed(2)}\n'
              'Balance After: ${_asDouble(m['balanceAfter']).toStringAsFixed(2)}',
            ),
          ),
          const SizedBox(height: 12),
          if (status == 'pending')
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _approveRequest(docId, m),
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                ),
                ElevatedButton.icon(
                  onPressed: _busy ? null : () => _rejectRequest(docId, m),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payout Center'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by docId / uid / service / enterprise / status...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_mainTab() == 'history')
              Column(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _historyFilter == 'all',
                        onSelected: (_) => setState(() => _historyFilter = 'all'),
                      ),
                      ChoiceChip(
                        label: const Text('Approved'),
                        selected: _historyFilter == 'approved',
                        onSelected: (_) => setState(() => _historyFilter = 'approved'),
                      ),
                      ChoiceChip(
                        label: const Text('Rejected'),
                        selected: _historyFilter == 'rejected',
                        onSelected: (_) => setState(() => _historyFilter = 'rejected'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('payout_requests')
                    .orderBy('createdAt', descending: true)
                    .limit(500)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snap.hasError) {
                    return Center(
                      child: Text('Erreur payout_requests: ${snap.error}'),
                    );
                  }

                  final allDocs = snap.data?.docs ?? [];

                  final pendingCount = allDocs.where((d) {
                    final s = (d.data()['status'] ?? '').toString().toLowerCase();
                    return s == 'pending';
                  }).length;

                  final approvedCount = allDocs.where((d) {
                    final s = (d.data()['status'] ?? '').toString().toLowerCase();
                    return s == 'approved';
                  }).length;

                  final rejectedCount = allDocs.where((d) {
                    final s = (d.data()['status'] ?? '').toString().toLowerCase();
                    return s == 'rejected';
                  }).length;

                  final filtered = allDocs.where((d) {
                    final m = d.data();
                    return _matchesMainTab(m) && _matchesSearch(m, d.id);
                  }).toList();

                  double visibleTotal = 0;
                  for (final d in filtered) {
                    visibleTotal += _asDouble(d.data()['amount']);
                  }

                  if (filtered.isEmpty) {
                    return ListView(
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _statBox('Pending', '$pendingCount', Colors.orange),
                            _statBox('Approved', '$approvedCount', Colors.green),
                            _statBox('Rejected', '$rejectedCount', Colors.red),
                            _statBox(
                              'Visible Total',
                              '${visibleTotal.toStringAsFixed(2)} USD',
                              Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _mainTab() == 'pending'
                                  ? 'Pa gen payout pending kounye a.'
                                  : 'Pa gen history pou filt sa a.',
                            ),
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
                          _statBox('Pending', '$pendingCount', Colors.orange),
                          _statBox('Approved', '$approvedCount', Colors.green),
                          _statBox('Rejected', '$rejectedCount', Colors.red),
                          _statBox(
                            'Visible Total',
                            '${visibleTotal.toStringAsFixed(2)} USD',
                            Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...filtered.map((d) => _buildRequestCard(d.id, d.data())),
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