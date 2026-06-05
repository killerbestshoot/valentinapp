import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class CommissionService {
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static Future<Map<String, int>> applyCommission(String txId) async {
    final db = FirebaseFirestore.instance;
    var applied = 0;
    var skipped = 0;

    await db.runTransaction((t) async {
      final txRef = db.collection('transactions').doc(txId);
      final txSnap = await t.get(txRef);

      if (!txSnap.exists) {
        skipped++;
        return;
      }

      final tx = txSnap.data() as Map<String, dynamic>;

      if (tx['commissionApplied'] == true) {
        skipped++;
        return;
      }

      final enterpriseId = (tx['enterpriseId'] ?? '').toString();
      final staffUid = (tx['staffUid'] ?? tx['agentUid'] ?? '').toString();

      if (enterpriseId.isEmpty || staffUid.isEmpty) {
        skipped++;
        t.update(txRef, {
          'commissionError': 'missing enterpriseId or staffUid',
          'commissionCheckedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final paymentAmount = _toDouble(
        tx['paymentAmount'] ?? tx['amount'] ?? tx['transferAmount'],
      );

      if (paymentAmount <= 0) {
        skipped++;
        t.update(txRef, {
          'commissionError': 'amount <= 0',
          'commissionCheckedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      final paymentCurrency =
          (tx['paymentCurrency'] ?? tx['currency'] ?? 'HTG').toString();

      final agentPercent = _toDouble(tx['agentCommissionPercent'] ?? 10);
      final ownerPercent = _toDouble(tx['ownerCommissionPercent'] ?? 20);

      final agentCommission = paymentAmount * agentPercent / 100;
      final ownerCommission = paymentAmount * ownerPercent / 100;

      final agentRef =
          db.collection('balances').doc('${enterpriseId}_$staffUid');
      final ownerRef = db.collection('balances').doc('${enterpriseId}_OWNER');

      final agentSnap = await t.get(agentRef);
      final ownerSnap = await t.get(ownerRef);

      final agentBalance = _toDouble(agentSnap.data()?['balance']);
      final ownerBalance = _toDouble(ownerSnap.data()?['balance']);

      t.set(
          agentRef,
          {
            'balance': agentBalance + agentCommission,
            'enterpriseId': enterpriseId,
            'uid': staffUid,
            'role': 'agent',
            'currency': paymentCurrency,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      t.set(
          ownerRef,
          {
            'balance': ownerBalance + ownerCommission,
            'enterpriseId': enterpriseId,
            'uid': 'OWNER',
            'role': 'owner',
            'currency': paymentCurrency,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      t.update(txRef, {
        'commissionApplied': true,
        'commissionAgent': agentCommission,
        'commissionOwner': ownerCommission,
        'agentCommissionPercent': agentPercent,
        'ownerCommissionPercent': ownerPercent,
        'commissionRule': 'percent_based',
        'commissionError': FieldValue.delete(),
        'commissionAppliedAt': FieldValue.serverTimestamp(),
      });

      final ledgerId = AppIds.ledger(seed: 'commission:$txId');
      t.set(db.collection('ledger').doc(ledgerId), {
        'ledgerId': ledgerId,
        'type': 'commission',
        'txId': txId,
        'enterpriseId': enterpriseId,
        'staffUid': staffUid,
        'paymentAmount': paymentAmount,
        'paymentCurrency': paymentCurrency,
        'agentPercent': agentPercent,
        'ownerPercent': ownerPercent,
        'agentCommission': agentCommission,
        'ownerCommission': ownerCommission,
        'createdAt': FieldValue.serverTimestamp(),
      });

      applied++;
    });

    return {'checked': 1, 'applied': applied, 'skipped': skipped};
  }

  static Future<Map<String, int>> runForEnterprise(String enterpriseId) async {
    final q = await FirebaseFirestore.instance
        .collection('transactions')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .where('commissionApplied', isEqualTo: false)
        .limit(100)
        .get();

    var checked = 0;
    var applied = 0;
    var skipped = 0;

    for (final d in q.docs) {
      checked++;
      final r = await applyCommission(d.id);
      applied += r['applied'] ?? 0;
      skipped += r['skipped'] ?? 0;
    }

    return {'checked': checked, 'applied': applied, 'skipped': skipped};
  }
}
