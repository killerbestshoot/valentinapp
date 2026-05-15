import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportsExportPage extends StatefulWidget {
  const ReportsExportPage({super.key});

  @override
  State<ReportsExportPage> createState() => _ReportsExportPageState();
}

class _ReportsExportPageState extends State<ReportsExportPage> {
  bool _loading = false;

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Future<void> _generateQuickReport() async {
    setState(() => _loading = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('transactions')
          .orderBy('createdAt', descending: true)
          .limit(300)
          .get();

      double totalVolume = 0;
      int totalTx = snap.docs.length;
      int delivered = 0;
      int paid = 0;
      int commissionApplied = 0;

      final Map<String, double> serviceTotals = {};

      for (final d in snap.docs) {
        final m = d.data();
        final amount = _asDouble(m['paymentAmount']);
        final service = (m['serviceName'] ?? 'unknown').toString();
        final status = (m['status'] ?? '').toString().toLowerCase();
        final paymentStatus = (m['paymentStatus'] ?? '').toString().toLowerCase();

        totalVolume += amount;
        if (status == 'delivered') delivered++;
        if (paymentStatus == 'paid') paid++;
        if (m['commissionApplied'] == true) commissionApplied++;

        serviceTotals[service] = (serviceTotals[service] ?? 0) + amount;
      }

      final rows = serviceTotals.keys.map((k) {
        return '$k: ${(serviceTotals[k] ?? 0).toStringAsFixed(2)} USD';
      }).join('\n');

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('Quick Report'),
            content: SingleChildScrollView(
              child: SelectableText(
                'Transactions: $totalTx\n'
                'Volume: ${totalVolume.toStringAsFixed(2)} USD\n'
                'Delivered: $delivered\n'
                'Paid: $paid\n'
                'Commission Applied: $commissionApplied\n\n'
                'Service Totals:\n$rows',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveReportStub() async {
    setState(() => _loading = true);

    try {
      final now = DateTime.now();

      await FirebaseFirestore.instance.collection('reports').add({
        'title': 'Quick Report ${now.toIso8601String()}',
        'type': 'quick_summary',
        'createdAt': Timestamp.fromDate(now),
        'status': 'generated',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report stub saved in Firestore.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur save report: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _actionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon, size: 32),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _loading ? null : onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Export'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'This page is a safe starter for reports. '
                        'You can generate a quick summary, save a report stub, '
                        'then later we can upgrade to PDF/Excel export.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _actionCard(
                    icon: Icons.analytics_outlined,
                    title: 'Generate Quick Report',
                    subtitle: 'Reads transactions and shows a summary dialog.',
                    onTap: _generateQuickReport,
                  ),
                  _actionCard(
                    icon: Icons.save_alt,
                    title: 'Save Report Stub',
                    subtitle: 'Creates a starter report record in Firestore.',
                    onTap: _saveReportStub,
                  ),
                ],
              ),
            ),
    );
  }
}