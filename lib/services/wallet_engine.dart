import 'package:cloud_firestore/cloud_firestore.dart';

class WalletEngine {
  WalletEngine._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static double _num(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
    }

  static Future<void> creditBalance({
    required String uid,
    required String enterpriseId,
    required double amount,
    required String type,
    required String note,
    String currency = 'USD',
    String role = 'agent',
    String enterpriseName = '',
    String serviceName = '',
    String sourceCollection = 'system',
    String sourceId = '',
    String txId = '',
    String status = 'posted',
    String createdBy = 'system',
    String createdByRole = 'system',
  }) async {
    final balanceRef = _db.collection('balances').doc('${enterpriseId}_$uid');
    final ledgerRef = _db.collection('ledger').doc();
    final historyRef = _db.collection('wallet_history').doc();

    await _db.runTransaction((tx) async {
      final balSnap = await tx.get(balanceRef);
      final balData = balSnap.data();

      final before = balSnap.exists ? _num(balData?['balance']) : 0.0;
      final after = before + amount;

      tx.set(balanceRef, {
        'uid': uid,
        'staffUid': uid,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'role': role,
        'currency': currency,
        'balance': after,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(ledgerRef, {
        'type': type,
        'direction': 'credit',
        'uid': uid,
        'role': role,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'amount': amount,
        'currency': currency,
        'beforeBalance': before,
        'afterBalance': after,
        'sourceCollection': sourceCollection,
        'sourceId': sourceId,
        'txId': txId,
        'serviceName': serviceName,
        'status': status,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'createdByRole': createdByRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(historyRef, {
        'uid': uid,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'role': role,
        'type': type,
        'direction': 'credit',
        'amount': amount,
        'currency': currency,
        'beforeBalance': before,
        'afterBalance': after,
        'note': note,
        'sourceCollection': sourceCollection,
        'sourceId': sourceId,
        'txId': txId,
        'serviceName': serviceName,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> debitBalance({
    required String uid,
    required String enterpriseId,
    required double amount,
    required String type,
    required String note,
    String currency = 'USD',
    String role = 'agent',
    String enterpriseName = '',
    String serviceName = '',
    String sourceCollection = 'system',
    String sourceId = '',
    String txId = '',
    String status = 'posted',
    String createdBy = 'system',
    String createdByRole = 'system',
  }) async {
    final balanceRef = _db.collection('balances').doc('${enterpriseId}_$uid');
    final ledgerRef = _db.collection('ledger').doc();
    final historyRef = _db.collection('wallet_history').doc();

    await _db.runTransaction((tx) async {
      final balSnap = await tx.get(balanceRef);
      final balData = balSnap.data();

      final before = balSnap.exists ? _num(balData?['balance']) : 0.0;
      final after = before - amount;

      tx.set(balanceRef, {
        'uid': uid,
        'staffUid': uid,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'role': role,
        'currency': currency,
        'balance': after,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      tx.set(ledgerRef, {
        'type': type,
        'direction': 'debit',
        'uid': uid,
        'role': role,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'amount': amount,
        'currency': currency,
        'beforeBalance': before,
        'afterBalance': after,
        'sourceCollection': sourceCollection,
        'sourceId': sourceId,
        'txId': txId,
        'serviceName': serviceName,
        'status': status,
        'note': note,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': createdBy,
        'createdByRole': createdByRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(historyRef, {
        'uid': uid,
        'enterpriseId': enterpriseId,
        'enterpriseName': enterpriseName,
        'role': role,
        'type': type,
        'direction': 'debit',
        'amount': amount,
        'currency': currency,
        'beforeBalance': before,
        'afterBalance': after,
        'note': note,
        'sourceCollection': sourceCollection,
        'sourceId': sourceId,
        'txId': txId,
        'serviceName': serviceName,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}