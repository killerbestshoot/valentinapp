import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String senderUid;
  final String receiverName;
  final String receiverPhone;
  final double amount;
  final String currency;
  final String status;
  final String? agentUid;
  final Timestamp createdAt;

  TransactionModel({
    required this.id,
    required this.senderUid,
    required this.receiverName,
    required this.receiverPhone,
    required this.amount,
    required this.currency,
    required this.status,
    this.agentUid,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderUid': senderUid,
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      'amount': amount,
      'currency': currency,
      'status': status,
      'agentUid': agentUid,
      'createdAt': createdAt,
    };
  }

  factory TransactionModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TransactionModel(
      id: doc.id,
      senderUid: d['senderUid'],
      receiverName: d['receiverName'],
      receiverPhone: d['receiverPhone'],
      amount: (d['amount'] as num).toDouble(),
      currency: d['currency'],
      status: d['status'],
      agentUid: d['agentUid'],
      createdAt: d['createdAt'],
    );
  }
}
