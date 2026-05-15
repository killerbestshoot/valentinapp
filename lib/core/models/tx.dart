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
    return Tx(
      id: id,
      type: (data['type'] ?? '').toString(),
      amount: (data['amount'] ?? 0) is int
          ? data['amount'] as int
          : int.tryParse('${data['amount']}') ?? 0,
      status: (data['status'] ?? '').toString(),
      receiptNo: (data['receiptNo'] ?? '').toString(),
      failReason: (data['failReason'] ?? '').toString(),
    );
  }
}
