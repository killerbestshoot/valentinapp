import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionStatus { draft, pending, success, failed, cancelled }

class TransactionModel {
  final String id;
  final String type;
  final double amount;
  final double fee;
  final double total;

  final String customerName;
  final String customerPhone;
  final String receiverName;
  final String externalRef;

  final String createdBy;
  final DateTime createdAt;
  final TransactionStatus status;

  TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.fee,
    required this.total,
    required this.customerName,
    required this.customerPhone,
    required this.receiverName,
    required this.externalRef,
    required this.createdBy,
    required this.createdAt,
    required this.status,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'amount': amount,
        'fee': fee,
        'total': total,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'receiverName': receiverName,
        'externalRef': externalRef,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status.name,
      };
}
