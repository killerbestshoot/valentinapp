import "package:flutter/material.dart";
import "package:mon_premye_app/pages/commission/commission_history_page.dart";
import "package:mon_premye_app/pages/commission/run_commission_page.dart";

class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _toolButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget page,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _open(context, page),
        icon: Icon(icon),
        label: Text(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Owner Dashboard"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "TOOLS",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _toolButton(
            context: context,
            title: "Run Commission",
            icon: Icons.play_arrow_outlined,
            page: const RunCommissionPage(),
          ),
          const SizedBox(height: 12),
          _toolButton(
            context: context,
            title: "Commission History",
            icon: Icons.history_outlined,
            page: const CommissionHistoryPage(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Auth Debug poko branche isit la."),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text("Auth Debug"),
            ),
          ),
        ],
      ),
    );
  }
}
