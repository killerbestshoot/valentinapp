import 'package:flutter/material.dart';

class MyTransactionsPage extends StatelessWidget {
  const MyTransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final transactions = <Map<String, String>>[
      {
        'title': 'TX001',
        'by': 'staffexcelsior3@gmail.com',
        'amount': '500',
        'status': 'success',
      },
      {
        'title': 'TX002',
        'by': 'kervensulysse106@gmail.com',
        'amount': '700',
        'status': 'pending',
      },
      {
        'title': 'TX003',
        'by': 'client@voupvapcash.com',
        'amount': '300',
        'status': 'submitted',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: const Color(0xFF13284A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: transactions.isEmpty
          ? const Center(
              child: Text(
                'Pa gen tranzaksyon pou kounye a.',
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final tx = transactions[index];
                return _TransactionCard(
                  txId: tx['title'] ?? '',
                  by: tx['by'] ?? '',
                  amount: tx['amount'] ?? '0',
                  status: tx['status'] ?? 'unknown',
                );
              },
            ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String txId;
  final String by;
  final String amount;
  final String status;

  const _TransactionCard({
    required this.txId,
    required this.by,
    required this.amount,
    required this.status,
  });

  Color _statusColor(String value) {
    switch (value.toLowerCase()) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return Colors.blue;
      case 'processing':
        return Colors.deepPurple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE6EBF2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF9EE7F0).withValues(alpha: 0.45),
            child: const Icon(
              Icons.receipt_long,
              color: Color(0xFF13284A),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tx: $txId',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'By: $by',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Status: $status',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF13284A),
            ),
          ),
        ],
      ),
    );
  }
}
