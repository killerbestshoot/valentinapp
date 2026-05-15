import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> submitPayoutRequest({
  required BuildContext context,
  required double amount,
  required String enterpriseId,
  required String serviceId,
  required String serviceName,
}) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User pa konekte')),
    );
    return;
  }

  if (amount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Amount must be greater than 0')),
    );
    return;
  }

  try {
    await FirebaseFirestore.instance.collection('payout_requests').add({
      'uid': user.uid,
      'enterpriseId': enterpriseId,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'amount': amount,
      'status': 'pending',
      'processed': false,
      'paidOut': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payout request voye')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Er: $e')),
    );
  }
}