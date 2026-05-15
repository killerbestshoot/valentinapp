import 'package:flutter/foundation.dart';

enum TxType { send, receive }

class DemoTransaction {
  final String id;
  final TxType type;
  final String service; // MonCash, NatCash, WU, CAM...
  final double amount;
  final String party; // moun / kliyan / benefisy
  final String phone;
  final String note;
  final DateTime createdAt;

  DemoTransaction({
    required this.id,
    required this.type,
    required this.service,
    required this.amount,
    required this.party,
    required this.phone,
    required this.note,
    required this.createdAt,
  });
}

class DemoAgentAccount {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime createdAt;

  DemoAgentAccount({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.createdAt,
  });
}

class DemoStore extends ChangeNotifier {
  DemoStore._();

  static final DemoStore instance = DemoStore._();

  final List<DemoTransaction> _transactions = [];
  final List<DemoAgentAccount> _agents = [];

  List<DemoTransaction> get transactions =>
      List.unmodifiable(_transactions.reversed);

  List<DemoAgentAccount> get agents => List.unmodifiable(_agents.reversed);

  void addSend({
    required String service,
    required double amount,
    required String toName,
    required String toPhone,
    String note = '',
  }) {
    _transactions.add(
      DemoTransaction(
        id: _id(),
        type: TxType.send,
        service: service,
        amount: amount,
        party: toName,
        phone: toPhone,
        note: note,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void addReceive({
    required String service,
    required double amount,
    required String fromName,
    required String fromPhone,
    String note = '',
  }) {
    _transactions.add(
      DemoTransaction(
        id: _id(),
        type: TxType.receive,
        service: service,
        amount: amount,
        party: fromName,
        phone: fromPhone,
        note: note,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void addAgent({
    required String name,
    required String email,
    required String phone,
  }) {
    _agents.add(
      DemoAgentAccount(
        id: _id(),
        name: name,
        email: email,
        phone: phone,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
}
