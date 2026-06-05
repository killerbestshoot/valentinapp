import "package:flutter/material.dart";
import "package:mon_premye_app/pages/agent/agents_page.dart";
import "package:mon_premye_app/pages/transactions/new_transaction_page.dart";
import "package:mon_premye_app/pages/payout/payout_page.dart";
import "package:mon_premye_app/pages/transactions/send_page.dart";
import "package:mon_premye_app/pages/settings/settings_page.dart";
import "package:mon_premye_app/pages/wallet/topup_page.dart";

class OwnerQuickActions extends StatelessWidget {
  const OwnerQuickActions({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _card({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Widget page,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context, page),
      child: Card(
        child: SizedBox(
          height: 120,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 30),
                const SizedBox(height: 10),
                Text(label),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "QUICK ACTIONS",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _card(
              context: context,
              label: "New Tx",
              icon: Icons.add_circle_outline,
              page: const NewTransactionPage(),
            ),
            _card(
              context: context,
              label: "Send",
              icon: Icons.send_outlined,
              page: const SendPage(),
            ),
            _card(
              context: context,
              label: "Payout",
              icon: Icons.payments_outlined,
              page: const PayoutPage(),
            ),
            _card(
              context: context,
              label: "Topup",
              icon: Icons.phone_android_outlined,
              page: const TopupPage(),
            ),
            _card(
              context: context,
              label: "Agents",
              icon: Icons.people_outline,
              page: const AgentsPage(),
            ),
            _card(
              context: context,
              label: "Settings",
              icon: Icons.settings_outlined,
              page: const SettingsPage(),
            ),
          ],
        ),
      ],
    );
  }
}
