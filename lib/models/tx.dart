class Tx {
  final String id;
  final String type;
  final int amount;
  final String status;
  final String receiptNo;
  final String failReason;

  Tx({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.receiptNo,
    required this.failReason,
  });

  static Tx fromDoc(String id, Map<String, dynamic> data) {
    final dynamic rawAmount = data['amount'];
    final int amount = rawAmount is int
        ? rawAmount
        : int.tryParse(rawAmount?.toString() ?? '') ?? 0;

    return Tx(
      id: id,
      type: (data['type'] ?? '').toString(),
      amount: amount,
      status: (data['status'] ?? '').toString(),
      receiptNo: (data['receiptNo'] ?? '').toString(),
      failReason: (data['failReason'] ?? '').toString(),
    );
  }
}
