import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreRepo {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createTransaction({
    required Map<String, dynamic> staff,
    required Map<String, dynamic> payload,
  }) async {
    final role = (staff['role'] ?? '').toString().trim().toLowerCase();
    if (role != 'agent') {
      throw Exception('Se agent slman ki ka kreye transaction.');
    }

    final enterpriseId = (staff['enterpriseId'] ?? '').toString().trim();
    final enterpriseName = (staff['enterpriseName'] ?? '').toString().trim();
    final staffUid = (staff['uid'] ?? '').toString().trim();
    final staffName = (staff['displayName'] ?? staff['fullName'] ?? 'Agent').toString().trim();

    if (enterpriseId.isEmpty || staffUid.isEmpty) {
      throw Exception('enterpriseId oswa staffUid manke sou staff profile la.');
    }

    final now = DateTime.now();
    final txId = (payload['txId'] ?? 'TXN_${now.millisecondsSinceEpoch}').toString();

    double asDouble(dynamic v, [double fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v.toDouble();
      if (v is double) return v;
      return double.tryParse(v.toString()) ?? fallback;
    }

    final paymentAmount = asDouble(payload['paymentAmount'] ?? payload['amount']);
    final transferAmount = asDouble(payload['transferAmount'] ?? payload['amount']);

    final data = <String, dynamic>{
      'txId': txId,
      'transactionId': txId,
      'enterpriseId': enterpriseId,
      'enterpriseName': enterpriseName,
      'staffUid': staffUid,
      'staffName': staffName,
      'staffRole': 'agent',

      'serviceName': (payload['serviceName'] ?? 'manual_tx').toString(),
      'category': (payload['category'] ?? 'transfer').toString(),

      'customerPhone': (payload['customerPhone'] ?? '').toString(),
      'beneficiaryPhone': (payload['beneficiaryPhone'] ?? '').toString(),
      'beneficiaryName': (payload['beneficiaryName'] ?? '').toString(),
      'note': (payload['note'] ?? '').toString(),

      'paymentAmount': paymentAmount,
      'paymentCurrency': (payload['paymentCurrency'] ?? 'USD').toString(),
      'transferAmount': transferAmount,
      'transferCurrency': (payload['transferCurrency'] ?? 'HTG').toString(),

      'status': (payload['status'] ?? 'delivered').toString(),
      'paymentStatus': (payload['paymentStatus'] ?? 'paid').toString(),

      'commissionAgent': asDouble(payload['commissionAgent'], 0),
      'commissionOwner': asDouble(payload['commissionOwner'], 0),
      'commissionApplied': false,

      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };

    await _db.collection('transactions').add(data);
  }
}