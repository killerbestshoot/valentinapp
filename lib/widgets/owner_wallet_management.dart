import "package:flutter/material.dart";
import "package:mon_premye_app/pages/auth/auth_debug_page.dart";
import "package:mon_premye_app/pages/commission/commission_history_page.dart";
import "package:mon_premye_app/pages/payout/payout_approval_page.dart";
import "package:mon_premye_app/pages/payout/payout_page.dart";
import "package:mon_premye_app/pages/commission/run_commission_page.dart";
import "package:mon_premye_app/pages/wallet/wallet_dashboard_page.dart";
import "package:mon_premye_app/pages/wallet/wallet_topup_approval_page.dart";

class OwnerWalletManagement extends StatelessWidget {
  const OwnerWalletManagement({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _toolButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Widget page,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _open(context, page),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "TOOLS",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _toolButton(
          context: context,
          label: "Run Commission",
          icon: Icons.percent_outlined,
          page: const RunCommissionPage(),
        ),
        const SizedBox(height: 12),
        _toolButton(
          context: context,
          label: "Commission History",
          icon: Icons.history_outlined,
          page: const CommissionHistoryPage(),
        ),
        const SizedBox(height: 12),
        _toolButton(
          context: context,
          label: "Wallet Dashboard",
          icon: Icons.account_balance_wallet_outlined,
          page: const WalletDashboardPage(),
        ),
        const SizedBox(height: 12),
        _toolButton(
          context: context,
          label: "Payout",
          icon: Icons.payments_outlined,
          page: const PayoutPage(),
        ),
        const SizedBox(height: 12),
        _toolButton(
          context: context,
          label: "Payout Approval",
          icon: Icons.verified_user_outlined,
          page: const PayoutApprovalPage(),
        ),
        const SizedBox(height: 12),
        _toolButton(
          context: context,
          label: "Wallet Topup Approval",
          icon: Icons.approval_outlined,
          page: const WalletTopupApprovalPage(),
        ),
        const SizedBox(height: 12),
        _toolButton(
          context: context,
          label: "Auth Debug",
          icon: Icons.bug_report_outlined,
          page: const AuthDebugPage(),
        ),
      ],
    );
  }
}
