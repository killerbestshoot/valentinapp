import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/dashboard_ui.dart';

class WalletTopupApprovalPage extends StatefulWidget {
  const WalletTopupApprovalPage({super.key});

  @override
  State<WalletTopupApprovalPage> createState() =>
      _WalletTopupApprovalPageState();
}

class _WalletTopupApprovalPageState extends State<WalletTopupApprovalPage> {
  static const String enterpriseId = 'ENT-001';
  static const String enterpriseName = 'VOUPVAPCASH';

  final Set<String> _loadingIds = <String>{};

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  String _fmt(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
    }
    return '-';
  }

  Future<void> _approve(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final id = doc.id;
    if (_loadingIds.contains(id)) return;

    setState(() => _loadingIds.add(id));

    try {
      final db = FirebaseFirestore.instance;

      await db.runTransaction((tx) async {
        final reqRef = db.collection('wallet_topup_requests').doc(id);
        final reqSnap = await tx.get(reqRef);

        if (!reqSnap.exists) {
          throw Exception('Request la pa egziste');
        }

        final reqData = reqSnap.data() ?? {};
        final liveStatus = (reqData['status'] ?? '').toString().toLowerCase();
        if (liveStatus != 'pending') {
          throw Exception('Request sa deja trete');
        }

        final liveAmount = _asDouble(reqData['amount']);
        final liveTargetUid =
            (reqData['targetUid'] ?? reqData['uid'] ?? '').toString();
        final liveTargetRole =
            (reqData['targetRole'] ?? 'agent').toString().toLowerCase();
        final liveTargetName =
            (reqData['targetName'] ?? liveTargetUid).toString();
        final requestedBy = (reqData['requestedBy'] ?? '').toString();
        final requestedByName = (reqData['requestedByName'] ?? '').toString();
        final requestedByRole = (reqData['requestedByRole'] ?? '').toString();

        if (liveAmount <= 0) {
          throw Exception('Amount pa valab');
        }

        if (liveTargetUid.isEmpty) {
          throw Exception('targetUid manke');
        }

        final liveBalanceDocId = liveTargetRole == 'owner'
            ? '${enterpriseId}_OWNER'
            : '${enterpriseId}_$liveTargetUid';

        final balRef = db.collection('balances').doc(liveBalanceDocId);
        final balSnap = await tx.get(balRef);

        final before =
            balSnap.exists ? _asDouble(balSnap.data()?['balance']) : 0;
        final after = before + liveAmount;

        tx.set(
          balRef,
          {
            'uid': liveTargetUid,
            'role': liveTargetRole,
            'enterpriseId': enterpriseId,
            'enterpriseName': enterpriseName,
            'currency': 'USD',
            'balance': after,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!balSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        tx.update(reqRef, {
          'status': 'approved',
          'processed': true,
          'approvedAt': FieldValue.serverTimestamp(),
          'balanceBefore': before,
          'balanceAfter': after,
          'balanceDocId': liveBalanceDocId,
        });

        final historyRef = db.collection('wallet_history').doc();
        tx.set(historyRef, {
          'type': 'topup_approved',
          'enterpriseId': enterpriseId,
          'enterpriseName': enterpriseName,
          'targetUid': liveTargetUid,
          'targetName': liveTargetName,
          'targetRole': liveTargetRole,
          'amount': liveAmount,
          'currency': 'USD',
          'balanceBefore': before,
          'balanceAfter': after,
          'requestId': reqRef.id,
          'requestedBy': requestedBy,
          'requestedByName': requestedByName,
          'requestedByRole': requestedByRole,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Topup approved')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approve error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingIds.remove(id));
      }
    }
  }

  Future<void> _reject(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final id = doc.id;
    if (_loadingIds.contains(id)) return;

    setState(() => _loadingIds.add(id));

    try {
      final db = FirebaseFirestore.instance;
      final reqRef = db.collection('wallet_topup_requests').doc(id);

      await db.runTransaction((tx) async {
        final snap = await tx.get(reqRef);
        if (!snap.exists) {
          throw Exception('Request la pa egziste');
        }

        final data = snap.data() ?? {};
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status != 'pending') {
          throw Exception('Request sa deja trete');
        }

        tx.update(reqRef, {
          'status': 'rejected',
          'processed': true,
          'rejectedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Topup rejected')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reject error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingIds.remove(id));
      }
    }
  }

  Widget _requestCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final loading = _loadingIds.contains(doc.id);

    final amount = _asDouble(data['amount']);
    final currency = (data['currency'] ?? 'USD').toString();
    final targetName =
        (data['targetName'] ?? data['targetUid'] ?? data['uid'] ?? '')
            .toString();
    final targetRole = (data['targetRole'] ?? '').toString();
    final requestedByName = (data['requestedByName'] ?? '').toString();
    final requestedByRole = (data['requestedByRole'] ?? '').toString();
    final createdAt = _fmt(data['createdAt']);

    return DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$targetName - ${amount.toStringAsFixed(2)} $currency',
            style: const TextStyle(
              color: DashboardColors.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          DashboardInfoRow(label: 'Role', value: targetRole),
          DashboardInfoRow(label: 'Requested by', value: requestedByName),
          DashboardInfoRow(label: 'By role', value: requestedByRole),
          DashboardInfoRow(label: 'Date', value: createdAt),
          DashboardInfoRow(label: 'Request ID', value: doc.id),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: loading ? null : () => _approve(doc),
                  icon: const Icon(Icons.check),
                  label: Text(loading ? 'Loading...' : 'Approve'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : () => _reject(doc),
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('wallet_topup_requests')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return DashboardPage(
      title: 'Topup approval',
      children: [
        const DashboardHero(
          icon: Icons.fact_check_outlined,
          title: 'Wallet topup approval',
          subtitle: 'Review pending balance requests before funds move.',
        ),
        const SizedBox(height: 18),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return DashboardPanel(
                child: Text('Erreur Firestore: ${snapshot.error}'),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const DashboardPanel(
                child: Text('Pa gen topup request pending'),
              );
            }

            return Column(
              children: [
                for (final doc in docs) ...[
                  _requestCard(doc),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
