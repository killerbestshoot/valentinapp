import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _loading = false;
  String _log = '';
  String? _lastTxId;

  void _setLog(String msg) {
    if (!mounted) return;
    setState(() => _log = msg);
  }

  Future<void> _readMyUserDoc() async {
    final u = _auth.currentUser;
    if (u == null) return _setLog('Pa konekte.');

    setState(() => _loading = true);
    try {
      final ref = _db.collection('users').doc(u.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        _setLog('users/${u.uid} pa egziste (dokiman user la pa kreye).');
        return;
      }
      _setLog('users/${u.uid} egziste: OK');
    } on FirebaseException catch (e) {
      _setLog('Firestore read error: ${e.code} ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createTransaction() async {
    final u = _auth.currentUser;
    if (u == null) return _setLog('Pa konekte.');

    setState(() => _loading = true);
    try {
      final txId = AppIds.transaction(
        seed: '${u.uid}:debug:${DateTime.now().toIso8601String()}',
      );
      await _db.collection('transactions').doc(txId).set({
        'txId': txId,
        'transactionId': txId,
        'uid': u.uid,
        'amount': 100,
        'status': 'created',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _lastTxId = txId;
      _setLog('transactions/$txId kreye: OK');
    } on FirebaseException catch (e) {
      _setLog('Firestore tx create error: ${e.code} ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  //  MEN FONKSYON OU TE VOYE A  li la, anndan State la (se sa ki te manke a)
  Future<void> _updateLastTransactionStatus() async {
    final u = _auth.currentUser;
    if (u == null) return _setLog('Pa konekte.');
    final id = _lastTxId;
    if (id == null) return _setLog('Pa gen tx ank. Kreye yon tx an premye.');

    setState(() => _loading = true);
    try {
      final ref = _db.collection('transactions').doc(id);

      final snap = await ref.get();
      if (!snap.exists) return _setLog('Tx pa egziste.');

      final data = snap.data()!;
      final current = (data['status'] ?? 'created').toString();

      final next = switch (current) {
        'created' => 'processing',
        'processing' => 'completed',
        'completed' => 'completed',
        _ => 'processing',
      };

      await ref.update({
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _setLog('Tx update OK: status=$next');
    } on FirebaseException catch (e) {
      _setLog('Firestore tx update error: ${e.code} ${e.message}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final u = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Konekte', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('UID: ${u?.uid ?? "-"}'),
            Text('Phone: ${u?.phoneNumber ?? "-"}'),
            const Divider(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _readMyUserDoc,
                child: const Text('1) Ekri users/(uid)'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _createTransaction,
                child: const Text('2) Kreye Transaction'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _updateLastTransactionStatus,
                child: const Text('3) Li / Dnye Transaction'),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            const SizedBox(height: 12),
            Text(_log, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
