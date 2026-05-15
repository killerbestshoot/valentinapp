import "package:flutter/material.dart";
import "package:mon_premye_app/widgets/owner_balance_card.dart";
import "package:mon_premye_app/widgets/owner_quick_actions.dart";
import "package:mon_premye_app/widgets/owner_wallet_management.dart";

class OwnerDashboardPage extends StatelessWidget {
  const OwnerDashboardPage({super.key});

  static const String enterpriseId = "ENT-001";
  static const String enterpriseName = "VOUPVAPCASH";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("OWNER DASHBOARD"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          OwnerBalanceCard(
            enterpriseId: enterpriseId,
            enterpriseName: enterpriseName,
          ),
          SizedBox(height: 16),
          OwnerQuickActions(),
          SizedBox(height: 16),
          OwnerWalletManagement(),
        ],
      ),
    );
  }
}
