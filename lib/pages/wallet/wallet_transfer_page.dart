import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class WalletTransferPage extends StatefulWidget {
  const WalletTransferPage({super.key});

  @override
  State<WalletTransferPage> createState() => _WalletTransferPageState();
}

class _WalletTransferPageState extends State<WalletTransferPage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  bool loading = false;

  String myRole = '';
  String myEnterpriseId = '';
  String myEnterpriseName = '';
  String myDisplayName = '';

  double myWalletBalance = 0;

  Map<String, dynamic>? selectedReceiver;

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  Future<void> _loadMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(user.uid).get();
    final entSnap = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (entSnap.docs.isEmpty) {
      throw Exception('enterprise_users pa jwenn');
    }

    final ent = entSnap.docs.first.data();

    String foundRole =
        (userDoc.data()?['role'] ?? '').toString().toLowerCase().trim();
    if (foundRole.isEmpty) {
      foundRole = (ent['role'] ?? '').toString().toLowerCase().trim();
    }

    final walletRef = db.collection('wallets').doc(user.uid);
    final walletSnap = await walletRef.get();

    if (!walletSnap.exists) {
      await walletRef.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'enterpriseId': (ent['enterpriseId'] ?? '').toString(),
        'role': foundRole,
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final freshWallet = await walletRef.get();
    final walletData = freshWallet.data() ?? <String, dynamic>{};

    setState(() {
      myRole = foundRole;
      myEnterpriseId = (ent['enterpriseId'] ?? '').toString();
      myEnterpriseName = (ent['enterpriseName'] ?? '').toString();
      myDisplayName = (ent['displayName'] ?? user.email ?? '').toString();
      myWalletBalance = _toDouble(walletData['balance']);
    });
  }

  Future<void> _searchReceiver() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final q = searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Antre email, uid, oswa non moun nan')),
      );
      return;
    }

    setState(() {
      loading = true;
      selectedReceiver = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final staffSnap = await db
          .collection('enterprise_users')
          .where('enterpriseId', isEqualTo: myEnterpriseId)
          .where('isActive', isEqualTo: true)
          .get();

      Map<String, dynamic>? found;

      for (final doc in staffSnap.docs) {
        final d = doc.data();
        final uid = (d['uid'] ?? '').toString();
        final email = (d['email'] ?? '').toString().toLowerCase();
        final displayName = (d['displayName'] ?? '').toString().toLowerCase();
        final role = (d['role'] ?? '').toString().toLowerCase();

        final match = uid.toLowerCase().contains(q) ||
            email.contains(q) ||
            displayName.contains(q);

        if (match) {
          if (uid == user.uid) {
            continue;
          }

          found = {
            'uid': uid,
            'email': (d['email'] ?? '').toString(),
            'displayName': (d['displayName'] ?? '').toString(),
            'role': role,
            'enterpriseId': (d['enterpriseId'] ?? '').toString(),
          };
          break;
        }
      }

      if (found == null) {
        throw Exception('Receiver pa jwenn oswa se menm user la');
      }

      final walletRef = db.collection('wallets').doc(found['uid']);
      final walletSnap = await walletRef.get();

      if (!walletSnap.exists) {
        await walletRef.set({
          'uid': found['uid'],
          'email': found['email'],
          'enterpriseId': found['enterpriseId'],
          'role': found['role'],
          'balance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final freshWalletSnap = await walletRef.get();
      final walletData = freshWalletSnap.data() ?? <String, dynamic>{};

      found['walletBalance'] = _toDouble(walletData['balance']);

      setState(() {
        selectedReceiver = found;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER SEARCH: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _transferWallet() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return;
    }

    if (selectedReceiver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chwazi receiver an premye')),
      );
      return;
    }

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final note = noteController.text.trim();

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount dwe plis pase 0')),
      );
      return;
    }

    if ((selectedReceiver!['uid'] ?? '').toString() == currentUser.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ou pa ka transfere bay tt ou')),
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final db = FirebaseFirestore.instance;
      final receiverUid = (selectedReceiver!['uid'] ?? '').toString();

      final senderWalletRef = db.collection('wallets').doc(currentUser.uid);
      final receiverWalletRef = db.collection('wallets').doc(receiverUid);

      final transferId = AppIds.transfer(
        seed:
            '$myEnterpriseId:${currentUser.uid}:$receiverUid:${DateTime.now().toIso8601String()}',
      );
      final senderLedgerId = AppIds.ledger(seed: 'debit:$transferId');
      final receiverLedgerId = AppIds.ledger(seed: 'credit:$transferId');
      final senderLedgerRef =
          db.collection('wallet_ledger').doc(senderLedgerId);
      final receiverLedgerRef =
          db.collection('wallet_ledger').doc(receiverLedgerId);

      await db.runTransaction((tx) async {
        final senderWalletSnap = await tx.get(senderWalletRef);
        final receiverWalletSnap = await tx.get(receiverWalletRef);

        if (!senderWalletSnap.exists) {
          throw Exception('Wallet sender a pa egziste');
        }

        if (!receiverWalletSnap.exists) {
          throw Exception('Wallet receiver a pa egziste');
        }

        final senderWalletData =
            senderWalletSnap.data() as Map<String, dynamic>;
        final receiverWalletData =
            receiverWalletSnap.data() as Map<String, dynamic>;

        final senderBefore = _toDouble(senderWalletData['balance']);
        final receiverBefore = _toDouble(receiverWalletData['balance']);

        if (senderBefore < amount) {
          throw Exception('Wallet sender a pa sifi ($senderBefore < $amount)');
        }

        final senderAfter = senderBefore - amount;
        final receiverAfter = receiverBefore + amount;

        tx.update(senderWalletRef, {
          'balance': senderAfter,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.update(receiverWalletRef, {
          'balance': receiverAfter,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        tx.set(senderLedgerRef, {
          'ledgerId': senderLedgerId,
          'type': 'wallet_transfer',
          'action': 'wallet_transfer_debit',
          'transferId': transferId,
          'enterpriseId': myEnterpriseId,
          'enterpriseName': myEnterpriseName,
          'uid': currentUser.uid,
          'staffName': myDisplayName,
          'staffRole': myRole,
          'targetUid': (selectedReceiver!['uid'] ?? '').toString(),
          'targetName': (selectedReceiver!['displayName'] ?? '').toString(),
          'targetRole': (selectedReceiver!['role'] ?? '').toString(),
          'amount': amount,
          'balanceBefore': senderBefore,
          'balanceAfter': senderAfter,
          'reviewedBy': currentUser.uid,
          'reviewedByName': currentUser.email ?? '',
          'reviewerRole': myRole,
          'reviewNotes': note,
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(receiverLedgerRef, {
          'ledgerId': receiverLedgerId,
          'type': 'wallet_transfer',
          'action': 'wallet_transfer_credit',
          'transferId': transferId,
          'enterpriseId': myEnterpriseId,
          'enterpriseName': myEnterpriseName,
          'uid': (selectedReceiver!['uid'] ?? '').toString(),
          'staffName': (selectedReceiver!['displayName'] ?? '').toString(),
          'staffRole': (selectedReceiver!['role'] ?? '').toString(),
          'sourceUid': currentUser.uid,
          'sourceName': myDisplayName,
          'sourceRole': myRole,
          'amount': amount,
          'balanceBefore': receiverBefore,
          'balanceAfter': receiverAfter,
          'reviewedBy': currentUser.uid,
          'reviewedByName': currentUser.email ?? '',
          'reviewerRole': myRole,
          'reviewNotes': note,
          'createdAt': FieldValue.serverTimestamp(),
        });

        final transferRef = db.collection('wallet_transfers').doc(transferId);
        tx.set(transferRef, {
          'transferId': transferId,
          'enterpriseId': myEnterpriseId,
          'enterpriseName': myEnterpriseName,
          'fromUid': currentUser.uid,
          'fromName': myDisplayName,
          'fromRole': myRole,
          'toUid': (selectedReceiver!['uid'] ?? '').toString(),
          'toName': (selectedReceiver!['displayName'] ?? '').toString(),
          'toRole': (selectedReceiver!['role'] ?? '').toString(),
          'amount': amount,
          'fromBalanceBefore': senderBefore,
          'fromBalanceAfter': senderAfter,
          'toBalanceBefore': receiverBefore,
          'toBalanceAfter': receiverAfter,
          'note': note,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      final refreshedMyWallet = await senderWalletRef.get();
      final refreshedReceiverWallet = await receiverWalletRef.get();

      setState(() {
        myWalletBalance = _toDouble(
            (refreshedMyWallet.data() ?? <String, dynamic>{})['balance']);
        selectedReceiver = {
          ...selectedReceiver!,
          'walletBalance': _toDouble(
            (refreshedReceiverWallet.data() ?? <String, dynamic>{})['balance'],
          ),
        };
      });

      amountController.clear();
      noteController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet transfer fini + ledger ekri')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER TRANSFER: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadMyProfile();
  }

  @override
  void dispose() {
    searchController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roleLoaded = myRole.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Transfer'),
      ),
      body: !roleLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ROLE: $myRole'),
                        Text('ENTERPRISE: $myEnterpriseName'),
                        Text('ENTERPRISE ID: $myEnterpriseId'),
                        const SizedBox(height: 8),
                        Text(
                          'MY WALLET: ${_fmtMoney(myWalletBalance)} USD',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: searchController,
                  decoration: const InputDecoration(
                    labelText: 'Chche receiver pa email / uid / non',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: loading ? null : _searchReceiver,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child:
                          Text(loading ? 'Tanpri tann...' : 'Search Receiver'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (selectedReceiver != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RECEIVER FOUND',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _line('UID',
                              (selectedReceiver!['uid'] ?? '').toString()),
                          _line(
                              'Name',
                              (selectedReceiver!['displayName'] ?? '')
                                  .toString()),
                          _line('Email',
                              (selectedReceiver!['email'] ?? '').toString()),
                          _line('Role',
                              (selectedReceiver!['role'] ?? '').toString()),
                          _line(
                            'Wallet',
                            '${_fmtMoney(_toDouble(selectedReceiver!['walletBalance']))} USD',
                          ),
                        ],
                      ),
                    ),
                  ),
                if (selectedReceiver != null) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Transfer Amount',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: loading ? null : _transferWallet,
                      icon: const Icon(Icons.swap_horiz),
                      label: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          loading ? 'Tanpri tann...' : 'Transfer Wallet',
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
