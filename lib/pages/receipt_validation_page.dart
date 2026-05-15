import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'receipt_page.dart';

class ReceiptValidationPage extends StatefulWidget {
  const ReceiptValidationPage({super.key});

  @override
  State<ReceiptValidationPage> createState() => _ReceiptValidationPageState();
}

class _ReceiptValidationPageState extends State<ReceiptValidationPage> {
  final TextEditingController _txCtrl = TextEditingController();

  bool _loading = false;
  String _status = '';
  Color _color = Colors.grey;
  Map<String, dynamic>? _data;

  static const String _receiptSecret = 'VOUPVAPCASH_SECURE_V1_2026';

  String _s(dynamic v) => (v ?? '').toString();

  String _fmt2(dynamic v) {
    final n = double.tryParse(v.toString()) ?? 0;
    return n.toStringAsFixed(2);
  }

  String _buildSignature({
    required String txId,
    required String enterpriseId,
    required String paymentAmount,
    required String paymentCurrency,
    required String serviceId,
  }) {
    final raw = '$txId|$enterpriseId|$paymentAmount|$paymentCurrency|$serviceId|$_receiptSecret';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  Map<String, String> _parseInput(String raw) {
    final value = raw.trim();
    if (value.contains('|')) {
      final parts = value.split('|');
      final txId = parts.isNotEmpty ? parts.first.trim() : '';
      final signature = parts.length > 1 ? parts[1].trim() : '';
      return {
        'txId': txId,
        'signature': signature,
      };
    }
    return {
      'txId': value,
      'signature': '',
    };
  }

  Future<Map<String, dynamic>> _getProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(user.uid).get();
    final ent = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (ent.docs.isEmpty) {
      throw Exception('No enterprise');
    }

    final entData = ent.docs.first.data();

    return {
      'uid': user.uid,
      'displayName': (userDoc.data()?['displayName'] ?? '').toString(),
      'role': (entData['role'] ?? '').toString().toLowerCase().trim(),
      'enterpriseId': (entData['enterpriseId'] ?? '').toString(),
      'enterpriseName': (entData['enterpriseName'] ?? '').toString(),
    };
  }

  Future<void> _writeValidationLog({
    required String status,
    required String reason,
    required String validatedBy,
    required String validatedByName,
    required Map<String, dynamic> receiptData,
  }) async {
    final db = FirebaseFirestore.instance;

    await db.collection('receipt_validation_logs').add({
      'txId': _s(receiptData['txId']),
      'receiptId': _s(receiptData['receiptId']).isEmpty
          ? _s(receiptData['txId'])
          : _s(receiptData['receiptId']),
      'enterpriseId': _s(receiptData['enterpriseId']),
      'enterpriseName': _s(receiptData['enterpriseName']),
      'serviceName': _s(receiptData['serviceName']),
      'customerName': _s(receiptData['customerName']),
      'customerPhone': _s(receiptData['customerPhone']),
      'paymentAmount': receiptData['paymentAmount'],
      'paymentCurrency': _s(receiptData['paymentCurrency']),
      'validatedBy': validatedBy,
      'validatedByName': validatedByName,
      'status': status,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _validate() async {
    final parsed = _parseInput(_txCtrl.text);
    final txId = parsed['txId'] ?? '';
    final providedSignature = parsed['signature'] ?? '';

    if (txId.isEmpty) {
      setState(() {
        _status = 'Antre TxId oswa QR payload';
        _color = Colors.red;
        _data = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = '';
      _color = Colors.grey;
      _data = null;
    });

    try {
      final db = FirebaseFirestore.instance;
      final profile = await _getProfile();
      final enterpriseId = _s(profile['enterpriseId']);
      final uid = _s(profile['uid']);
      final validatedByName = _s(profile['displayName']);

      DocumentSnapshot<Map<String, dynamic>> doc =
          await db.collection('receipts').doc(txId).get();

      Map<String, dynamic>? data = doc.data();

      if (data == null) {
        final q = await db
            .collection('receipts')
            .where('txId', isEqualTo: txId)
            .limit(1)
            .get();

        if (q.docs.isNotEmpty) {
          data = q.docs.first.data();
          doc = q.docs.first;
        }
      }

      if (data == null) {
        await _writeValidationLog(
          status: 'invalid',
          reason: 'Receipt pa egziste',
          validatedBy: uid,
          validatedByName: validatedByName,
          receiptData: {
            'txId': txId,
            'receiptId': txId,
            'enterpriseId': enterpriseId,
            'enterpriseName': '',
            'serviceName': '',
            'customerName': '',
            'customerPhone': '',
            'paymentAmount': 0,
            'paymentCurrency': '',
          },
        );

        setState(() {
          _status = ' INVALID (pa egziste)';
          _color = Colors.red;
          _data = null;
        });
        return;
      }

      final receiptEnterprise = _s(data['enterpriseId']);
      final paymentAmount = _fmt2(data['paymentAmount']);
      final paymentCurrency = _s(data['paymentCurrency']);
      final serviceId = _s(data['serviceId']);
      final storedSignature = _s(data['receiptSignature']);

      final expectedSignature = _buildSignature(
        txId: txId,
        enterpriseId: receiptEnterprise,
        paymentAmount: paymentAmount,
        paymentCurrency: paymentCurrency,
        serviceId: serviceId,
      );

      bool suspicious = false;
      bool invalid = false;
      String reason = 'Receipt valid';

      if (storedSignature.isEmpty) {
        invalid = true;
        reason = 'Signature pa egziste';
      }

      if (!invalid && storedSignature != expectedSignature) {
        invalid = true;
        reason = 'Stored signature pa matche';
      }

      if (!invalid && providedSignature.isNotEmpty && providedSignature != expectedSignature) {
        invalid = true;
        reason = 'QR signature pa matche';
      }

      if (!invalid && receiptEnterprise != enterpriseId) {
        suspicious = true;
        reason = 'Receipt soti nan yon lt enterprise';
      }

      final rawCreatedAt = data['createdAt'] ?? data['receiptCreatedAt'];
      DateTime? createdAt;

      if (rawCreatedAt is Timestamp) {
        createdAt = rawCreatedAt.toDate();
      } else if (rawCreatedAt is String) {
        createdAt = DateTime.tryParse(rawCreatedAt);
      }

      if (!invalid && createdAt != null) {
        final age = DateTime.now().difference(createdAt).inDays;
        if (age > 30) {
          suspicious = true;
          reason = 'Receipt la gen plis pase 30 jou';
        }
      }

      final validationStatus = invalid
          ? 'invalid'
          : suspicious
              ? 'suspicious'
              : 'valid';

      await db.collection('receipts').doc(doc.id).update({
        'lastValidatedAt': FieldValue.serverTimestamp(),
        'lastValidatedBy': uid,
        'validationCount': FieldValue.increment(1),
        'lastValidationStatus': validationStatus,
      });

      await _writeValidationLog(
        status: validationStatus,
        reason: reason,
        validatedBy: uid,
        validatedByName: validatedByName,
        receiptData: data,
      );

      setState(() {
        _data = data;

        if (invalid) {
          _status = ' INVALID RECEIPT';
          _color = Colors.red;
        } else if (suspicious) {
          _status = ' SUSPICIOUS RECEIPT';
          _color = Colors.orange;
        } else {
          _status = ' VALID RECEIPT';
          _color = Colors.green;
        }
      });
    } catch (e) {
      setState(() {
        _status = 'ER: $e';
        _color = Colors.red;
        _data = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _line(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _txCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fraud Detection'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Antre TxId oswa QR payload: txId|signature',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _txCtrl,
            decoration: const InputDecoration(
              labelText: 'TxId oswa QR payload',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _loading ? null : _validate,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_loading ? 'Tanpri tann...' : 'CHECK RECEIPT'),
            ),
          ),
          const SizedBox(height: 16),
          if (_status.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                border: Border.all(color: _color),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  color: _color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          if (_data != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line('TxId', _s(_data!['txId'])),
                    _line('Service', _s(_data!['serviceName'])),
                    _line('Customer', _s(_data!['customerName'])),
                    _line('Phone', _s(_data!['customerPhone'])),
                    _line('Agent', _s(_data!['staffName'])),
                    _line('Enterprise', _s(_data!['enterpriseName'])),
                    _line(
                      'Amount',
                      '${_s(_data!['paymentAmount'])} ${_s(_data!['paymentCurrency'])}',
                    ),
                    _line(
                      'Signature',
                      _s(_data!['receiptSignature']).isEmpty
                          ? '-'
                          : _s(_data!['receiptSignature']).substring(0, 20),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReceiptPage(
                      transactionId: _s(_data!['txId']),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.receipt),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('OPEN RECEIPT'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
