import 'package:cloud_firestore/cloud_firestore.dart';

class Txn {
  final String id;
  final String agentUid;
  final String agentEmail;

  final String service; // MonCash / NatCash / Western Union / CAM Transf
  final String countryName; // Ayiti...
  final String countryIso; // HT...
  final String dialCode; // +509...

  final String customerName;
  final String customerPhone;

  final num amount;
  final String status; // pending / done / canceled (pou pita)

  final DateTime? createdAt;

  Txn({
    required this.id,
    required this.agentUid,
    required this.agentEmail,
    required this.service,
    required this.countryName,
    required this.countryIso,
    required this.dialCode,
    required this.customerName,
    required this.customerPhone,
    required this.amount,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'agentUid': agentUid,
        'agentEmail': agentEmail,
        'service': service,
        'countryName': countryName,
        'countryIso': countryIso,
        'dialCode': dialCode,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'amount': amount,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };

  static Txn fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['createdAt'];
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();

    return Txn(
      id: doc.id,
      agentUid: (d['agentUid'] ?? '').toString(),
      agentEmail: (d['agentEmail'] ?? '').toString(),
      service: (d['service'] ?? '').toString(),
      countryName: (d['countryName'] ?? '').toString(),
      countryIso: (d['countryIso'] ?? '').toString(),
      dialCode: (d['dialCode'] ?? '').toString(),
      customerName: (d['customerName'] ?? '').toString(),
      customerPhone: (d['customerPhone'] ?? '').toString(),
      amount: (d['amount'] is num)
          ? d['amount'] as num
          : num.tryParse((d['amount'] ?? '0').toString()) ?? 0,
      status: (d['status'] ?? 'pending').toString(),
      createdAt: dt,
    );
  }
}
