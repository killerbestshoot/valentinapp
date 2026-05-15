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
    transactions.add({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': sender,
      'receiver': receiver,
      'amount': amount,
      'date': DateTime.now().toIso8601String(),
      'status': 'success',
    });
  }
}
