import 'package:flutter/material.dart';

class FinalQaPage extends StatefulWidget {
  const FinalQaPage({super.key});

  @override
  State<FinalQaPage> createState() => _FinalQaPageState();
}

class _FinalQaPageState extends State<FinalQaPage> {
  final Map<String, bool> checks = {
    'Agent can open payout test page': false,
    'Agent can submit payout request': false,
    'Admin can open payout approvals': false,
    'Admin can approve payout': false,
    'Admin can reject payout': false,
    'History page loads correctly': false,
    'Notifications page loads correctly': false,
    'Unread badge updates correctly': false,
    'Dashboard loads correctly': false,
    'Role gate blocks unauthorized access': false,
    'Cross-enterprise access is blocked': false,
    'Firestore rules work correctly': false,
  };

  double get progress {
    final total = checks.length;
    final done = checks.values.where((v) => v).length;
    if (total == 0) return 0;
    return done / total;
  }

  int get completedCount => checks.values.where((v) => v).length;

  Widget buildCheckTile(String title, bool value) {
    return Card(
      child: CheckboxListTile(
        value: value,
        title: Text(title),
        onChanged: (newValue) {
          setState(() {
            checks[title] = newValue ?? false;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).toStringAsFixed(0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Final QA Checklist'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Completion Progress',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 12),
                  Text('$completedCount / ${checks.length} checks completed'),
                  Text('Estimated finish: $percent%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...checks.entries.map((entry) {
            return buildCheckTile(entry.key, entry.value);
          }),
        ],
      ),
    );
  }
}
