import 'package:mon_premye_app/services/shared/app_ids.dart';

class TransactionService {
  TransactionService._();
  static final TransactionService instance = TransactionService._();

  static final List<Map<String, dynamic>> transactions = [];

  List<Map<String, dynamic>> get allTransactions => transactions;

  void createTransaction({
    required String sender,
    required String receiver,
    required double amount,
  }) {
    final id = AppIds.transaction(
      seed: '$sender:$receiver:${DateTime.now().toIso8601String()}',
    );
    transactions.add({
      'id': id,
      'txId': id,
      'transactionId': id,
      'sender': sender,
      'receiver': receiver,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
      'status': 'success',
    });
  }
}
