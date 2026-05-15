class TransactionModel {

  final String id;
  final String sender;
  final String receiver;
  final double amount;

  final double ownerCommission;
  final double adminCommission;
  final double agentCommission;

  final DateTime date;

  TransactionModel({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.amount,
    required this.ownerCommission,
    required this.adminCommission,
    required this.agentCommission,
    required this.date,
  });

}
