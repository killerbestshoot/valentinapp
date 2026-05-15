import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminLiveCounters extends StatelessWidget {
  const AdminLiveCounters({super.key});

  Widget _badgeCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _countBlacklist(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int n = 0;
    for (final d in docs) {
      final m = d.data();
      final c = (m['customerRiskStatus'] ?? '').toString().toLowerCase();
      final b = (m['beneficiaryRiskStatus'] ?? '').toString().toLowerCase();
      if (c == 'blacklist' || b == 'blacklist') {
        n++;
      }
    }
    return n;
  }

  int _countWatchlist(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    int n = 0;
    for (final d in docs) {
      final m = d.data();
      final c = (m['customerRiskStatus'] ?? '').toString().toLowerCase();
      final b = (m['beneficiaryRiskStatus'] ?? '').toString().toLowerCase();
      if (c == 'watchlist' || b == 'watchlist') {
        n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .snapshots(),
      builder: (context, txSnap) {
        if (!txSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final txDocs = txSnap.data!.docs;
        final blacklistCount = _countBlacklist(txDocs);
        final watchlistCount = _countWatchlist(txDocs);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('payout_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, payoutSnap) {
            if (!payoutSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final pendingPayouts = payoutSnap.data!.docs.length;
            final notificationsCount =
                pendingPayouts + blacklistCount + watchlistCount;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _badgeCard(
                  title: 'Notifications',
                  count: notificationsCount,
                  icon: Icons.notifications_active,
                  color: Colors.blue,
                ),
                _badgeCard(
                  title: 'Pending Payouts',
                  count: pendingPayouts,
                  icon: Icons.pending_actions,
                  color: Colors.indigo,
                ),
                _badgeCard(
                  title: 'Blacklist Alerts',
                  count: blacklistCount,
                  icon: Icons.gpp_bad,
                  color: Colors.red,
                ),
                _badgeCard(
                  title: 'Watchlist Alerts',
                  count: watchlistCount,
                  icon: Icons.warning_amber,
                  color: Colors.orange,
                ),
              ],
            );
          },
        );
      },
    );
  }
}