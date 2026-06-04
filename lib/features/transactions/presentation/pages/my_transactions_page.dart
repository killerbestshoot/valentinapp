import 'package:flutter/material.dart';

import '../../domain/get_transactions_use_case.dart';
import '../../models/transaction_model.dart';

class MyTransactionsPage extends StatelessWidget {
  const MyTransactionsPage({super.key});

  static const _emptyState = Center(
    child: Text(
      'Pa gen tranzaksyon pou kounye a.',
      style: TextStyle(fontSize: 16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final useCase = GetTransactionsUseCase();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      appBar: AppBar(
        title: const Text('Transactions'),
        backgroundColor: const Color(0xFF13284A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<List<TransactionModel>>(
        stream: useCase.execute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Echèk chaje tranzaksyon yo: ${snapshot.error}'),
              ),
            );
          }

          final transactions = snapshot.data ?? [];
          if (transactions.isEmpty) {
            return _emptyState;
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: transactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _TransactionCard(
                txId: tx.id,
                by: tx.clientName,
                amount: tx.amount.toStringAsFixed(2),
                status: tx.status,
                service: tx.service,
              );
            },
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
  final String service;

  const _TransactionCard({
    required this.txId,
    required this.by,
    required this.amount,
    required this.status,
    this.service = '',
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
                if (service.isNotEmpty)
                  Text(
                    'Service: $service',
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                if (service.isNotEmpty) const SizedBox(height: 6),
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
