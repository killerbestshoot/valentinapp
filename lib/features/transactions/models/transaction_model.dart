import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel {
  final String id;
  final String clientName;
  final String phone;
  final double amount;
  final String country;
  final String service;
  final String status;
  final DateTime createdAt;

  TransactionModel({
    required this.id,
    required this.clientName,
    required this.phone,
    required this.amount,
    required this.country,
    required this.service,
    required this.status,
    required this.createdAt,
  });

  factory TransactionModel.fromSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? <String, dynamic>{};
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : DateTime.now();

    return TransactionModel(
      id: snapshot.id,
      clientName: (data['clientName'] ?? '').toString(),
      phone: (data['phone'] ?? '').toString(),
      amount: (data['amount'] is num ? (data['amount'] as num).toDouble() : 0.0),
      country: (data['country'] ?? '').toString(),
      service: (data['service'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      createdAt: createdAt,
    );
  }
}
