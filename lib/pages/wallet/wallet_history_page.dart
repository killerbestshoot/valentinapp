import 'package:flutter/material.dart';

import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/widgets/async_view.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

/// Istorik wallet: chak mouvman ak sòld anvan / apre.
///
/// Li li `wallet_ledger` la, ki ekri nan MENM tranzaksyon ak sòld la. Donk
/// chak kòb ki antre oswa sòti gen yon liy — rechaj, komisyon, transfè,
/// ranbousman. Anvan, `enterpriseId` te kode an di (`ENT-001`).
class WalletHistoryPage extends StatelessWidget {
  const WalletHistoryPage({super.key, this.uid});

  /// Staff pou montre. `null` = moun ki konekte a.
  final String? uid;

  @override
  Widget build(BuildContext context) {
    final targetUid = uid ?? AuthRepositoryProvider.instance.currentUser?.uid ?? '';

    return DashboardPage(
      title: 'Istorik wallet',
      children: [
        const DashboardHero(
          icon: Icons.history,
          title: 'Istorik wallet',
          subtitle: 'Chak mouvman kòb, ak sòld anvan ak apre.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: AsyncView<List<LedgerEntry>>(
            load: () => WalletApi.instance.ledger(targetUid, limit: 100),
            isEmpty: (rows) => rows.isEmpty,
            emptyMessage: 'Pa gen mouvman ankò.',
            builder: (context, rows, _) => Column(
              children: rows.map((entry) {
                final color = entry.isCredit ? const Color(0xFF15803D) : const Color(0xFFB91C1C);
                final sign = entry.isCredit ? '+' : '−';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        entry.isCredit ? Icons.south_west : Icons.north_east,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.note.isEmpty ? entry.type : entry.note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: DashboardColors.ink,
                              ),
                            ),
                            Text(
                              '${entry.balanceBefore.toStringAsFixed(2)} → '
                              '${entry.balanceAfter.toStringAsFixed(2)} ${entry.currency}',
                              style: const TextStyle(color: DashboardColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$sign${entry.amount.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.w900, color: color),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
