import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

double walletToDouble(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v.toDouble();
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class WalletService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> getEnterpriseIdForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User pa konekte');

    final q = await _db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw Exception('enterprise_users pa jwenn pou user sa a');
    }

    final enterpriseId =
        (q.docs.first.data()['enterpriseId'] ?? '').toString().trim();

    if (enterpriseId.isEmpty) {
      throw Exception('enterpriseId vid pou user sa a');
    }

    return enterpriseId;
  }

  static Future<String> getRoleForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';

    final userDoc = await _db.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      final data = userDoc.data() as Map<String, dynamic>;
      final role = (data['role'] ?? '').toString().trim().toLowerCase();
      if (role.isNotEmpty) return role;
    }

    final q = await _db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (q.docs.isNotEmpty) {
      return (q.docs.first.data()['role'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
    }

    return '';
  }

  static Future<void> ensureWalletForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User pa konekte');

    final enterpriseId = await getEnterpriseIdForCurrentUser();
    final role = await getRoleForCurrentUser();

    final ref = _db.collection('wallets').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'enterpriseId': enterpriseId,
        'role': role,
        'balance': 0.0,
        'reserved': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final data = snap.data() as Map<String, dynamic>;
      final hasReserved = data.containsKey('reserved');

      await ref.set({
        'uid': user.uid,
        'email': user.email ?? '',
        'enterpriseId': enterpriseId,
        'role': role,
        if (!hasReserved) 'reserved': 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> walletStreamForCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }
    return _db.collection('wallets').doc(user.uid).snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> walletHistory(String uid) {
    return _db
        .collection('wallet_logs')
        .where('uid', isEqualTo: uid)
        
        .snapshots();
  }

  static Future<void> topupWallet({
    required String targetUid,
    required double amount,
    required String reason,
  }) async {
    final admin = FirebaseAuth.instance.currentUser;
    if (admin == null) throw Exception('Admin pa konekte');
    if (amount <= 0) throw Exception('Amount pa valid');

    final walletRef = _db.collection('wallets').doc(targetUid);
    final logRef = _db.collection('wallet_logs').doc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(walletRef);

      if (!snap.exists) throw Exception('Wallet pa egziste');

      final data = snap.data() as Map<String, dynamic>;
      final balance = walletToDouble(data['balance']);
      final newBalance = balance + amount;

      tx.update(walletRef, {
        'balance': newBalance,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(logRef, {
        'type': 'topup',
        'uid': targetUid,
        'amount': amount,
        'balanceBefore': balance,
        'balanceAfter': newBalance,
        'reason': reason,
        'doneBy': admin.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> lockBalance({
    required String uid,
    required double amount,
  }) async {
    if (amount <= 0) throw Exception('Montant pa valid');

    final walletRef = _db.collection('wallets').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(walletRef);

      if (!snap.exists) {
        throw Exception('Wallet pa egziste');
      }

      final data = snap.data() as Map<String, dynamic>;

      final balance = walletToDouble(data['balance']);
      final reserved = walletToDouble(data['reserved']);
      final available = balance - reserved;

      if (available < amount) {
        throw Exception('Balans disponib pa sifi');
      }

      final newReserved = reserved + amount;

      tx.update(walletRef, {
        'reserved': newReserved,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final log = _db.collection('wallet_logs').doc();

      tx.set(log, {
        'type': 'lock',
        'uid': uid,
        'amount': amount,
        'reservedBefore': reserved,
        'reservedAfter': newReserved,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> submitWithdrawRequest({
    required double amount,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User pa konekte');

    if (amount <= 0) {
      throw Exception('Montant dwe plis pase 0');
    }

    final enterpriseId = await getEnterpriseIdForCurrentUser();
    final role = await getRoleForCurrentUser();

    await ensureWalletForCurrentUser();

    final walletRef = _db.collection('wallets').doc(user.uid);
    final walletSnap = await walletRef.get();

    if (!walletSnap.exists) {
      throw Exception('Wallet pa egziste');
    }

    final walletData = walletSnap.data() as Map<String, dynamic>;
    final walletBalance = walletToDouble(walletData['balance']);
    final reserved = walletToDouble(walletData['reserved']);
    final available = walletBalance - reserved;

    if (available < amount) {
      throw Exception('Wallet disponib pa sifi. Available: $available');
    }

    await lockBalance(
      uid: user.uid,
      amount: amount,
    );

    await _db.collection('payout_requests').add({
      'uid': user.uid,
      'email': user.email ?? '',
      'enterpriseId': enterpriseId,
      'amount': amount,
      'currency': 'USD',
      'type': 'withdraw',
      'status': 'pending',
      'processed': false,
      'paidOut': false,
      'role': role,
      'walletBalanceBeforeRequest': walletBalance,
      'walletReservedBeforeRequest': reserved,
      'walletAvailableBeforeRequest': available,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> approveWithdraw({
    required String uid,
    required double amount,
  }) async {
    final walletRef = _db.collection('wallets').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(walletRef);

      if (!snap.exists) {
        throw Exception('Wallet pa egziste');
      }

      final data = snap.data() as Map<String, dynamic>;

      final balance = walletToDouble(data['balance']);
      final reserved = walletToDouble(data['reserved']);

      if (reserved < amount) {
        throw Exception('Reserved pa sifi');
      }

      final newBalance = balance - amount;
      final newReserved = reserved - amount;

      tx.update(walletRef, {
        'balance': newBalance,
        'reserved': newReserved,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final log = _db.collection('wallet_logs').doc();

      tx.set(log, {
        'type': 'withdraw_approved',
        'uid': uid,
        'amount': amount,
        'balanceBefore': balance,
        'balanceAfter': newBalance,
        'reservedBefore': reserved,
        'reservedAfter': newReserved,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  static Future<void> rejectWithdraw({
    required String uid,
    required double amount,
  }) async {
    final walletRef = _db.collection('wallets').doc(uid);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(walletRef);

      if (!snap.exists) {
        throw Exception('Wallet pa egziste');
      }

      final data = snap.data() as Map<String, dynamic>;
      final reserved = walletToDouble(data['reserved']);

      if (reserved < amount) {
        throw Exception('Reserved pa sifi pou reject');
      }

      final newReserved = reserved - amount;

      tx.update(walletRef, {
        'reserved': newReserved,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final log = _db.collection('wallet_logs').doc();

      tx.set(log, {
        'type': 'withdraw_rejected',
        'uid': uid,
        'amount': amount,
        'reservedBefore': reserved,
        'reservedAfter': newReserved,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}