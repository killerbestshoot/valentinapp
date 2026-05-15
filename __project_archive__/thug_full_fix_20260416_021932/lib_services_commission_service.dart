import 'package:cloud_firestore/cloud_firestore.dart';

class CommissionService {
  CommissionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static double _num(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  static String _ownerBalanceDocId(String enterpriseId) {
    return '${enterpriseId}_OWNER';
  }

  static String _staffBalanceDocId({
    required String enterpriseId,
    required String uid,
  }) {
    return '${enterpriseId}_$uid';
  }

  static Future<void> applyCommission({
    required String txId,
    String? enterpriseId,
    String? staffUid,
    num? amount,
  }) async {
    final txRef = _db.collection('transactions').doc(txId);

    await _db.runTransaction((trx) async {
      final txSnap = await trx.get(txRef);

      if (!txSnap.exists) {
        throw Exception('Transaction not found');
      }

      final txData = txSnap.data() as Map<String, dynamic>;

      final alreadyApplied = txData['commissionApplied'] == true;
      if (alreadyApplied) {
        throw Exception('Commission already applied');
      }

      final resolvedEnterpriseId =
          ((txData['enterpriseId'] ?? enterpriseId) ?? '').toString().trim();

      final resolvedEnterpriseName =
          (txData['enterpriseName'] ?? '').toString().trim();

      final resolvedStaffUid =
          ((txData['staffUid'] ?? txData['uid'] ?? staffUid) ?? '')
              .toString()
              .trim();

      final resolvedStaffRole =
          (txData['staffRole'] ?? txData['role'] ?? 'agent')
              .toString()
              .trim();

      if (resolvedEnterpriseId.isEmpty) {
        throw Exception('enterpriseId missing in transaction');
      }

      if (resolvedStaffUid.isEmpty) {
        throw Exception('staffUid missing in transaction');
      }

      final status =
          (txData['status'] ?? '').toString().trim().toLowerCase();
      final paymentStatus =
          (txData['paymentStatus'] ?? 'paid').toString().trim().toLowerCase();

      if (status.isNotEmpty && status != 'delivered') {
        throw Exception('Transaction not delivered');
      }

      if (paymentStatus.isNotEmpty && paymentStatus != 'paid') {
        throw Exception('Transaction not paid');
      }

      final commissionAgent = _num(txData['commissionAgent']);
      final commissionOwner = _num(txData['commissionOwner']);

      final agentDocId = _staffBalanceDocId(
        enterpriseId: resolvedEnterpriseId,
        uid: resolvedStaffUid,
      );

      final ownerDocId = _ownerBalanceDocId(resolvedEnterpriseId);

      final agentRef = _db.collection('balances').doc(agentDocId);
      final ownerRef = _db.collection('balances').doc(ownerDocId);

      final agentSnap = await trx.get(agentRef);
      final ownerSnap = await trx.get(ownerRef);

      final agentData = agentSnap.data() ?? <String, dynamic>{};
      final ownerData = ownerSnap.data() ?? <String, dynamic>{};

      final agentBefore = _num(agentData['balance']);
      final ownerBefore = _num(ownerData['balance']);

      final agentAfter = agentBefore + commissionAgent;
      final ownerAfter = ownerBefore + commissionOwner;

      trx.set(
        agentRef,
        {
          'uid': resolvedStaffUid,
          'role': resolvedStaffRole.isEmpty ? 'agent' : resolvedStaffRole,
          'enterpriseId': resolvedEnterpriseId,
          'enterpriseName': resolvedEnterpriseName,
          'balance': agentAfter,
          'currency':
              (agentData['currency'] ?? txData['paymentCurrency'] ?? 'USD')
                  .toString(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (!agentSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      trx.set(
        ownerRef,
        {
          'uid': (ownerData['uid'] ?? 'OWNER').toString(),
          'role': 'owner',
          'enterpriseId': resolvedEnterpriseId,
          'enterpriseName': resolvedEnterpriseName,
          'balance': ownerAfter,
          'currency':
              (ownerData['currency'] ?? txData['paymentCurrency'] ?? 'USD')
                  .toString(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (!ownerSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      trx.update(txRef, {
        'commissionApplied': true,
        'commissionAppliedAt': FieldValue.serverTimestamp(),
        'commissionAgent': commissionAgent,
        'commissionOwner': commissionOwner,
        'agentBalanceDocId': agentDocId,
        'ownerBalanceDocId': ownerDocId,
        'agentBalanceBefore': agentBefore,
        'agentBalanceAfter': agentAfter,
        'ownerBalanceBefore': ownerBefore,
        'ownerBalanceAfter': ownerAfter,
      });
    });
  }
}