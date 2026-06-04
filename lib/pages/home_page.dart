import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_transaction_page.dart';
import 'receipt_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static const _ink = Color(0xFF172116);
  static const _muted = Color(0xFF667365);
  static const _surface = Color(0xFFF4F8F1);
  static const _brand = Color(0xFF123D2B);

  String _s(dynamic v) => (v ?? '').toString().trim();

  @override
  Widget build(BuildContext context) {
    final stream = FirebaseFirestore.instance
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        foregroundColor: _ink,
        titleSpacing: 24,
        title: const Text(
          'VOUPVAPCASH',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          IconButton(
            tooltip: 'Rafrechi',
            onPressed: () {},
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Dekonekte',
            onPressed: () => _confirmLogout(context),
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _StateMessage(
              icon: Icons.error_outline,
              title: 'Erreur transactions',
              message: '${snap.error}',
            );
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;
          final stats = _DashboardStats.fromDocs(docs);

          return LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16,
                  12,
                  isWide ? 32 : 16,
                  32,
                ),
                children: [
                  _Header(
                    isWide: isWide,
                    onCreate: () => _openCreateTransaction(context),
                  ),
                  const SizedBox(height: 18),
                  _StatsGrid(stats: stats, isWide: isWide),
                  const SizedBox(height: 18),
                  isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _TransactionsPanel(
                                docs: docs,
                                read: _s,
                                onOpen: (id) => _openReceipt(context, id),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 3,
                              child: _OperationsPanel(
                                stats: stats,
                                onCreate: () => _openCreateTransaction(context),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _OperationsPanel(
                              stats: stats,
                              onCreate: () => _openCreateTransaction(context),
                            ),
                            const SizedBox(height: 18),
                            _TransactionsPanel(
                              docs: docs,
                              read: _s,
                              onOpen: (id) => _openReceipt(context, id),
                            ),
                          ],
                        ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _openCreateTransaction(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateTransactionPage()),
    );
  }

  void _openReceipt(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ReceiptPage(transactionId: id)),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Dekonekte?'),
        content: const Text('Ou vle soti nan kont sa a?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Anile'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.logout),
            label: const Text('Dekonekte'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.isWide,
    required this.onCreate,
  });

  final bool isWide;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWide ? 28 : 20),
      decoration: BoxDecoration(
        color: HomePage._brand,
        borderRadius: BorderRadius.circular(8),
      ),
      child: isWide
          ? Row(
              children: [
                const Expanded(child: _HeaderCopy()),
                const SizedBox(width: 24),
                _CreateButton(onPressed: onCreate),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _HeaderCopy(),
                const SizedBox(height: 18),
                _CreateButton(onPressed: onCreate),
              ],
            ),
    );
  }
}

class _HeaderCopy extends StatelessWidget {
  const _HeaderCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Admin dashboard',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Suivi transactions, statuts, ak operasyon rapid.',
          style: TextStyle(
            color: Color(0xFFDDE8D8),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: HomePage._brand,
        minimumSize: const Size(210, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: const Icon(Icons.add_circle_outline),
      label: const Text(
        'Nouvo transaction',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.stats,
    required this.isWide,
  });

  final _DashboardStats stats;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MetricCard(
        icon: Icons.receipt_long_outlined,
        label: 'Transactions',
        value: '${stats.total}',
        accent: const Color(0xFF1565C0),
      ),
      _MetricCard(
        icon: Icons.schedule_outlined,
        label: 'Pending',
        value: '${stats.pending}',
        accent: const Color(0xFFF57F17),
      ),
      _MetricCard(
        icon: Icons.check_circle_outline,
        label: 'Delivered',
        value: '${stats.delivered}',
        accent: const Color(0xFF2E7D32),
      ),
      _MetricCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Volume',
        value: stats.volumeLabel,
        accent: const Color(0xFF6A1B9A),
      ),
    ];

    return GridView.count(
      crossAxisCount: isWide ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: isWide ? 2.4 : 1.7,
      children: cards,
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomePage._muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: HomePage._ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionsPanel extends StatelessWidget {
  const _TransactionsPanel({
    required this.docs,
    required this.read,
    required this.onOpen,
  });

  final List<QueryDocumentSnapshot<Object?>> docs;
  final String Function(dynamic value) read;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Icon(Icons.list_alt_outlined, color: HomePage._brand),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dènye transactions',
                    style: TextStyle(
                      color: HomePage._ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (docs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Text(
                'Pa gen transaction ankò.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HomePage._muted),
              ),
            )
          else
            ...docs.map((doc) {
              final data = doc.data();
              final map =
                  data is Map<String, dynamic> ? data : <String, dynamic>{};
              final service = read(map['serviceName']);
              final name = read(map['customerName']);
              final phone = read(map['customerPhone']);
              final amount = read(map['paymentAmount']);
              final currency = read(map['paymentCurrency']);
              final status = read(map['status']);

              return _TransactionTile(
                id: doc.id,
                service: service,
                customerName: name,
                phone: phone,
                amount: amount,
                currency: currency,
                status: status,
                onTap: () => onOpen(doc.id),
              );
            }),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.id,
    required this.service,
    required this.customerName,
    required this.phone,
    required this.amount,
    required this.currency,
    required this.status,
    required this.onTap,
  });

  final String id;
  final String service;
  final String customerName;
  final String phone;
  final String amount;
  final String currency;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName =
        customerName.isEmpty ? 'Kliyan pa disponib' : customerName;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F8EE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                color: HomePage._brand,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        service.isEmpty ? 'Service' : service,
                        style: const TextStyle(
                          color: HomePage._ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '$amount $currency'.trim(),
                        style: const TextStyle(
                          color: HomePage._brand,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      _StatusPill(status: status),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$displayName • ${phone.isEmpty ? 'Telefòn pa disponib' : phone}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomePage._muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: $id',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: HomePage._muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: HomePage._muted),
          ],
        ),
      ),
    );
  }
}

class _OperationsPanel extends StatelessWidget {
  const _OperationsPanel({
    required this.stats,
    required this.onCreate,
  });

  final _DashboardStats stats;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Operations',
            style: TextStyle(
              color: HomePage._ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 12),
          const _HealthRow(
            label: 'App',
            value: 'Connecte',
            icon: Icons.cloud_done_outlined,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(height: 10),
          _HealthRow(
            label: 'Queue pending',
            value: '${stats.pending}',
            icon: Icons.pending_actions_outlined,
            color: const Color(0xFFF57F17),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              backgroundColor: HomePage._brand,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Nouvo transaction'),
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: HomePage._muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: HomePage._ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final delivered = normalized == 'delivered' ||
        normalized == 'livre' ||
        normalized == 'livrée';
    final label = status.trim().isEmpty ? 'pending' : status.trim();
    final color = delivered ? const Color(0xFF2E7D32) : const Color(0xFFF57F17);
    final fill = delivered ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DashboardStats {
  const _DashboardStats({
    required this.total,
    required this.pending,
    required this.delivered,
    required this.volume,
    required this.currency,
  });

  final int total;
  final int pending;
  final int delivered;
  final double volume;
  final String currency;

  String get volumeLabel {
    final value = volume == volume.roundToDouble()
        ? volume.toStringAsFixed(0)
        : volume.toStringAsFixed(2);
    return currency.isEmpty ? value : '$value $currency';
  }

  factory _DashboardStats.fromDocs(List<QueryDocumentSnapshot<Object?>> docs) {
    var pending = 0;
    var delivered = 0;
    var volume = 0.0;
    var currency = '';

    for (final doc in docs) {
      final data = doc.data();
      if (data is! Map<String, dynamic>) continue;

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'delivered' || status == 'livre' || status == 'livrée') {
        delivered++;
      } else {
        pending++;
      }

      final rawAmount = data['paymentAmount'];
      if (rawAmount is num) {
        volume += rawAmount.toDouble();
      } else {
        volume += double.tryParse(rawAmount?.toString() ?? '') ?? 0;
      }

      if (currency.isEmpty) {
        currency = (data['paymentCurrency'] ?? '').toString().trim();
      }
    }

    return _DashboardStats(
      total: docs.length,
      pending: pending,
      delivered: delivered,
      volume: volume,
      currency: currency,
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: HomePage._muted),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: HomePage._ink,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HomePage._muted),
            ),
          ],
        ),
      ),
    );
  }
}
