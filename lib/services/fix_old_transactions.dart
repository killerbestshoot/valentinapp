import 'package:cloud_firestore/cloud_firestore.dart';

class FixOldTransactions {
  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v.toDouble();
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static Future<void> run() async {
    final db = FirebaseFirestore.instance;

    final q = await db.collection('transactions').get();

    for (final doc in q.docs) {
      final data = doc.data();

      final amount = _toDouble(
        data['paymentAmount'] ??
        data['transferAmount'] ??
        data['amount']
      );

      if (amount <= 0) continue;

      final agentCommission = amount * 0.10;
      final ownerCommission = amount * 0.20;

      await doc.reference.update({
        'commissionAgent': agentCommission,
        'commissionOwner': ownerCommission,
        'commissionApplied': true,
        'commissionRule': 'agent_10_owner_20_FIXED',
        'commissionFixedAt': FieldValue.serverTimestamp(),
      });

      print("Fixed: ${doc.id}");
    }
  }
}
