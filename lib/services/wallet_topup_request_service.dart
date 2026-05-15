import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

double topupToDouble(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

class WalletTopupRequestService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Map<String, dynamic>> getMyProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    String role =
        (userDoc.data()?['role'] ?? '').toString().toLowerCase().trim();

    final entSnap = await _db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (entSnap.docs.isEmpty) {
      throw Exception('enterprise_users pa jwenn');
    }

    final ent = entSnap.docs.first.data();

    if (role.isEmpty) {
      role = (ent['role'] ?? '').toString().toLowerCase().trim();
    }

    return {
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': (ent['displayName'] ?? user.email ?? '').toString(),
      'role': role,
      'enterpriseId': (ent['enterpriseId'] ?? '').toString(),
      'enterpriseName': (ent['enterpriseName'] ?? '').toString(),
    };
  }

  static Future<Map<String, dynamic>> findStaffInEnterprise(String query) async {
    final profile = await getMyProfile();
    final enterpriseId = (profile['enterpriseId'] ?? '').toString();

    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      throw Exception('Antre email, uid, oswa non staff la');
    }

    final staffSnap = await _db
        .collection('enterprise_users')
        .where('enterpriseId', isEqualTo: enterpriseId)
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
      throw Exception('Staff pa jwenn nan enterprise sa a');
    }

    final walletRef = _db.collection('wallets').doc(found['uid']);
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

    final freshWallet = await walletRef.get();
    found['walletBalance'] =
        topupToDouble((freshWallet.data() ?? <String, dynamic>{})['balance']);

    return found;
  }

  static Future<void> createTopupRequest({
    required Map<String, dynamic> targetStaff,
    required double amount,
    required String note,
  }) async {
    if (amount <= 0) {
      throw Exception('Amount dwe plis pase 0');
    }

    final profile = await getMyProfile();
    final role = (profile['role'] ?? '').toString();

    if (role != 'owner' && role != 'administrator' && role != 'admin') {
      throw Exception('Se owner/admin slman ki ka kreye topup request');
    }

    await _db.collection('wallet_topup_requests').add({
      'type': 'wallet_topup',
      'status': 'pending',
      'processed': false,
      'approved': false,
      'enterpriseId': (profile['enterpriseId'] ?? '').toString(),
      'enterpriseName': (profile['enterpriseName'] ?? '').toString(),
      'targetUid': (targetStaff['uid'] ?? '').toString(),
      'targetEmail': (targetStaff['email'] ?? '').toString(),
      'targetName': (targetStaff['displayName'] ?? '').toString(),
      'targetRole': (targetStaff['role'] ?? '').toString(),
      'amount': amount,
      'currency': 'USD',
      'note': note,
      'requestedBy': (profile['uid'] ?? '').toString(),
      'requestedByName': (profile['displayName'] ?? '').toString(),
      'requestedByRole': role,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> approveTopupRequest(String requestId) async {
    final profile = await getMyProfile();
    final role = (profile['role'] ?? '').toString();

    if (role != 'owner' && role != 'administrator' && role != 'admin') {
      throw Exception('Se owner/admin slman ki ka approve topup');
    }

    final requestRef = _db.collection('wallet_topup_requests').doc(requestId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(requestRef);
      if (!reqSnap.exists) {
        throw Exception('Topup request pa egziste');
      }

      final req = reqSnap.data() as Map<String, dynamic>;
      final status = (req['status'] ?? '').toString().toLowerCase().trim();
      final processed = req['processed'] == true;

      if (processed || status != 'pending') {
        throw Exception('Topup request sa a deja trete');
      }

      final targetUid = (req['targetUid'] ?? '').toString();
      final amount = topupToDouble(req['amount']);

      if (targetUid.isEmpty) {
        throw Exception('targetUid manke');
      }
      if (amount <= 0) {
        throw Exception('amount pa valid');
      }

      final walletRef = _db.collection('wallets').doc(targetUid);
      final walletSnap = await tx.get(walletRef);

      if (!walletSnap.exists) {
        throw Exception('Wallet target la pa egziste');
      }

      final walletData = walletSnap.data() as Map<String, dynamic>;
      final before = topupToDouble(walletData['balance']);
      final after = before + amount;

      tx.update(walletRef, {
        'balance': after,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.update(requestRef, {
        'status': 'approved',
        'processed': true,
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': (profile['uid'] ?? '').toString(),
        'approvedByName': (profile['displayName'] ?? '').toString(),
        'approvedByRole': role,
        'walletBalanceBefore': before,
        'walletBalanceAfter': after,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final ledgerRef = _db.collection('wallet_ledger').doc();
      tx.set(ledgerRef, {
        'type': 'wallet_topup',
        'action': 'wallet_credit_topup',
        'requestId': requestId,
        'enterpriseId': (profile['enterpriseId'] ?? '').toString(),
        'enterpriseName': (profile['enterpriseName'] ?? '').toString(),
        'uid': targetUid,
        'staffName': (req['targetName'] ?? '').toString(),
        'staffRole': (req['targetRole'] ?? '').toString(),
        'amount': amount,
        'balanceBefore': before,
        'balanceAfter': after,
        'reviewedBy': (profile['uid'] ?? '').toString(),
        'reviewedByName': (profile['displayName'] ?? '').toString(),
        'reviewerRole': role,
        'reviewNotes': (req['note'] ?? '').toString(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> rejectTopupRequest(String requestId, {String note = ''}) async {
    final profile = await getMyProfile();
    final role = (profile['role'] ?? '').toString();

    if (role != 'owner' && role != 'administrator' && role != 'admin') {
      throw Exception('Se owner/admin slman ki ka reject topup');
    }

    final requestRef = _db.collection('wallet_topup_requests').doc(requestId);

    await _db.runTransaction((tx) async {
      final reqSnap = await tx.get(requestRef);
      if (!reqSnap.exists) {
        throw Exception('Topup request pa egziste');
      }

      final req = reqSnap.data() as Map<String, dynamic>;
      final status = (req['status'] ?? '').toString().toLowerCase().trim();
      final processed = req['processed'] == true;

      if (processed || status != 'pending') {
        throw Exception('Topup request sa a deja trete');
      }

      tx.update(requestRef, {
        'status': 'rejected',
        'processed': true,
        'approved': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': (profile['uid'] ?? '').toString(),
        'rejectedByName': (profile['displayName'] ?? '').toString(),
        'rejectedByRole': role,
        'rejectNote': note,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}