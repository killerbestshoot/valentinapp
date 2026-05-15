import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/wallet_service.dart';

double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v.toDouble();
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class WithdrawApprovalPage extends StatelessWidget {
  const WithdrawApprovalPage({super.key});

  Future<String> _getEnterpriseId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final q = await FirebaseFirestore.instance
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return '';
    return (q.docs.first.data()['enterpriseId'] ?? '').toString().trim();
  }

  Future<String> _getRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      if (role.isNotEmpty) return role;
    }

    final q = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      return (q.docs.first.data()['role'] ?? '').toString().trim().toLowerCase();
    }

    return '';
  }

  Future<void> approve(BuildContext context, QueryDocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;

      final requestUid = (data['uid'] ?? '').toString().trim();
      final enterpriseId = (data['enterpriseId'] ?? '').toString().trim();
      final amount = toDouble(data['amount']);

      if (requestUid.isEmpty) throw Exception('uid manke');
      if (enterpriseId.isEmpty) throw Exception('enterpriseId manke');
      if (amount <= 0) throw Exception('amount pa valid');

      final db = FirebaseFirestore.instance;
      final enterpriseRef = db.collection('enterprises').doc(enterpriseId);
      final walletRef = db.collection('wallets').doc(requestUid);
      final logRef = db.collection('payout_logs').doc();

      await db.runTransaction((tx) async {
        final freshReq = await tx.get(doc.reference);
        if (!freshReq.exists) throw Exception('Request pa egziste');

        final freshReqData = freshReq.data() as Map<String, dynamic>;
        if ((freshReqData['processed'] ?? false) == true) {
          throw Exception('Request deja trete');
        }
        if ((freshReqData['status'] ?? '').toString() != 'pending') {
          throw Exception('Request pa pending ank');
        }

        final entSnap = await tx.get(enterpriseRef);
        if (!entSnap.exists) throw Exception('Enterprise pa egziste');

        final walletSnap = await tx.get(walletRef);
        if (!walletSnap.exists) throw Exception('Wallet pa egziste pou user sa a');

        final entData = entSnap.data() as Map<String, dynamic>;
        final walletData = walletSnap.data() as Map<String, dynamic>;

        final enterpriseBalance = toDouble(entData['balance']);
        final walletBalance = toDouble(walletData['balance']);
        final walletReserved = toDouble(walletData['reserved']);

        if (enterpriseBalance < amount) {
          throw Exception('Enterprise balance pa sifi ($enterpriseBalance < $amount)');
        }

        if (walletReserved < amount) {
          throw Exception('Reserved pa sifi nan wallet ($walletReserved < $amount)');
        }

        final newEnterpriseBalance = enterpriseBalance - amount;

        tx.update(enterpriseRef, {
          'balance': newEnterpriseBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(doc.reference, {
          'status': 'approved',
          'processed': true,
          'paidOut': true,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
          'approvedByRole': 'owner',
          'walletBalanceBefore': walletBalance,
          'walletReservedBefore': walletReserved,
          'enterpriseBalanceBefore': enterpriseBalance,
          'enterpriseBalanceAfter': newEnterpriseBalance,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(logRef, {
          'type': 'withdraw_approved',
          'requestId': doc.id,
          'uid': requestUid,
          'enterpriseId': enterpriseId,
          'amount': amount,
          'walletBalanceBefore': walletBalance,
          'walletReservedBefore': walletReserved,
          'enterpriseBalanceBefore': enterpriseBalance,
          'enterpriseBalanceAfter': newEnterpriseBalance,
          'approvedBy': FirebaseAuth.instance.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      await WalletService.approveWithdraw(
        uid: requestUid,
        amount: amount,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request approved + reserved retire nan wallet')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER: $e')),
      );
    }
  }

  Future<void> reject(BuildContext context, QueryDocumentSnapshot doc) async {
    try {
      final data = doc.data() as Map<String, dynamic>;
      final requestUid = (data['uid'] ?? '').toString().trim();
      final amount = toDouble(data['amount']);

      if (requestUid.isEmpty) throw Exception('uid manke');
      if (amount <= 0) throw Exception('amount pa valid');

      await doc.reference.update({
        'status': 'rejected',
        'processed': true,
        'paidOut': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': FirebaseAuth.instance.currentUser?.uid,
        'rejectedByRole': 'owner',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await WalletService.rejectWithdraw(
        uid: requestUid,
        amount: amount,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected + reserved lage')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: Future.wait([_getEnterpriseId(), _getRole()]),
      builder: (context, setupSnap) {
        if (!setupSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final enterpriseId = setupSnap.data![0];
        final role = setupSnap.data![1];

        if (role != 'owner' && role != 'administrator' && role != 'admin') {
          return Scaffold(
            appBar: AppBar(title: const Text('Withdraw Approval')),
            body: const Center(
              child: Text('Se owner/admin slman ki ka apwouve withdraw'),
            ),
          );
        }

        final stream = FirebaseFirestore.instance
            .collection('payout_requests')
            .where('enterpriseId', isEqualTo: enterpriseId)
            .where('status', isEqualTo: 'pending')
            .where('type', isEqualTo: 'withdraw');

        return Scaffold(
          appBar: AppBar(title: const Text('Withdraw Approval')),
          body: StreamBuilder<QuerySnapshot>(
            stream: stream.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.cast<QueryDocumentSnapshot>();

              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('UID: ${FirebaseAuth.instance.currentUser?.uid ?? ''} | ROLE: $role | ENT: $enterpriseId'),
                      const Expanded(
                        child: Center(
                          child: Text('Pa gen request pending pou enterprise sa a'),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'UID: ${FirebaseAuth.instance.currentUser?.uid ?? ''} | ROLE: $role | ENT: $enterpriseId',
                    ),
                  ),
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final amount = toDouble(data['amount']);

                    return Card(
                      child: ListTile(
                        title: Text('${amount.toStringAsFixed(2)} ${data['currency'] ?? 'USD'}'),
                        subtitle: Text(
                          'UID: ${data['uid']} | TYPE: ${data['type'] ?? ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => approve(context, doc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => reject(context, doc),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
