import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class CommissionAutomationPage extends StatefulWidget {
  const CommissionAutomationPage({super.key});

  @override
  State<CommissionAutomationPage> createState() =>
      _CommissionAutomationPageState();
}

class _CommissionAutomationPageState extends State<CommissionAutomationPage> {
  bool _busy = false;
  String _result = 'Pa gen run ank.';

  Future<void> _runNow() async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('runSundayCommissionsNow');
      final res = await callable.call();

      final data = Map<String, dynamic>.from(res.data as Map);
      setState(() {
        _result = 'RunId: ${data['runId']}\n'
            'Scanned: ${data['scanned']}\n'
            'Applied: ${data['applied']}\n'
            'Skipped: ${data['skipped']}\n'
            'Errors: ${data['errorsCount']}';
      });
    } catch (e) {
      setState(() {
        _result = 'Erreur: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Commission Automation',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'Chak dimanch a 11:00 PM, system nan ap kouri komisyon yo otomatikman. '
              'Ou ka peze bouton anba a pou teste li manylman.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: _busy ? null : _runNow,
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(
                _busy ? 'Ap kouri...' : 'Run Sunday Commissions Now',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: SelectableText(
              _result,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
