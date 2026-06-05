import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WalletTransferHistoryPage extends StatefulWidget {
  const WalletTransferHistoryPage({super.key});

  @override
  State<WalletTransferHistoryPage> createState() =>
      _WalletTransferHistoryPageState();
}

class _WalletTransferHistoryPageState extends State<WalletTransferHistoryPage> {
  String _filter = 'all';

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fmtDate(dynamic value) {
    final d = _parseDate(value);
    if (d.millisecondsSinceEpoch == 0) return '-';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  Widget _chip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) {
          setState(() {
            _filter = value;
          });
        },
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value.isEmpty ? '-' : value),
          ),
        ],
      ),
    );
  }

  bool _matchFilter(Map<String, dynamic> d, String currentUid) {
    final fromUid = (d['fromUid'] ?? '').toString();
    final toUid = (d['toUid'] ?? '').toString();

    if (_filter == 'incoming') return toUid == currentUid;
    if (_filter == 'outgoing') return fromUid == currentUid;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('User pa konekte'),
        ),
      );
    }

    final transferStream = FirebaseFirestore.instance
        .collection('wallet_transfers')
        .where(
          Filter.or(
            Filter('fromUid', isEqualTo: user.uid),
            Filter('toUid', isEqualTo: user.uid),
          ),
        )
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Transfer History'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: transferStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ER DATA: ${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs.toList()
            ..sort((a, b) {
              final da = _parseDate(a.data()['createdAt']);
              final db = _parseDate(b.data()['createdAt']);
              return db.compareTo(da);
            });

          final filteredDocs = docs.where((doc) {
            return _matchFilter(doc.data(), user.uid);
          }).toList();

          double incomingTotal = 0;
          double outgoingTotal = 0;

          for (final doc in docs) {
            final d = doc.data();
            final fromUid = (d['fromUid'] ?? '').toString();
            final toUid = (d['toUid'] ?? '').toString();
            final amount = _toDouble(d['amount']);

            if (toUid == user.uid) incomingTotal += amount;
            if (fromUid == user.uid) outgoingTotal += amount;
          }

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRANSFER SUMMARY',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('UID: ${user.uid}'),
                      Text('EMAIL: ${user.email ?? ''}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statCard(
                    'Incoming',
                    _fmtMoney(incomingTotal),
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                  const SizedBox(width: 10),
                  _statCard(
                    'Outgoing',
                    _fmtMoney(outgoingTotal),
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _chip('all', 'All'),
                    _chip('incoming', 'Incoming'),
                    _chip('outgoing', 'Outgoing'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (filteredDocs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Pa gen transfer history pou filt sa a'),
                  ),
                )
              else
                ...filteredDocs.map((doc) {
                  final d = doc.data();

                  final fromUid = (d['fromUid'] ?? '').toString();
                  final fromName = (d['fromName'] ?? '').toString();
                  final fromRole = (d['fromRole'] ?? '').toString();

                  final toUid = (d['toUid'] ?? '').toString();
                  final toName = (d['toName'] ?? '').toString();
                  final toRole = (d['toRole'] ?? '').toString();

                  final amount = _toDouble(d['amount']);
                  final note = (d['note'] ?? '').toString();
                  final transferId = (d['transferId'] ?? '').toString();

                  final isIncoming = toUid == user.uid;
                  final isOutgoing = fromUid == user.uid;

                  final color = isIncoming ? Colors.green : Colors.red;
                  final icon =
                      isIncoming ? Icons.arrow_downward : Icons.arrow_upward;
                  final direction = isIncoming
                      ? 'INCOMING'
                      : (isOutgoing ? 'OUTGOING' : 'TRANSFER');

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(icon, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  direction,
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                _fmtMoney(amount),
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _line('Transfer ID', transferId),
                          _line('From UID', fromUid),
                          _line('From Name', fromName),
                          _line('From Role', fromRole),
                          _line('To UID', toUid),
                          _line('To Name', toName),
                          _line('To Role', toRole),
                          _line('Amount', _fmtMoney(amount)),
                          _line(
                            'From Before',
                            _fmtMoney(_toDouble(d['fromBalanceBefore'])),
                          ),
                          _line(
                            'From After',
                            _fmtMoney(_toDouble(d['fromBalanceAfter'])),
                          ),
                          _line(
                            'To Before',
                            _fmtMoney(_toDouble(d['toBalanceBefore'])),
                          ),
                          _line(
                            'To After',
                            _fmtMoney(_toDouble(d['toBalanceAfter'])),
                          ),
                          _line('Note', note),
                          _line('Created At', _fmtDate(d['createdAt'])),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
