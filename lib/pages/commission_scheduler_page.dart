import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class CommissionSchedulerPage extends StatefulWidget {
  const CommissionSchedulerPage({super.key});

  @override
  State<CommissionSchedulerPage> createState() => _CommissionSchedulerPageState();
}

class _CommissionSchedulerPageState extends State<CommissionSchedulerPage> {
  bool _busy = false;
  String _result = 'Pa gen test ank.';

  Future<void> _runNow() async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('runSundayCommissionsNow');
      final response = await callable.call();
      final data = Map<String, dynamic>.from(response.data as Map);

      if (!mounted) return;
      setState(() {
        _result =
            'RunId: ${data['runId']}\n'
            'Scanned: ${data['scanned']}\n'
            'Applied: ${data['applied']}\n'
            'Skipped: ${data['skipped']}\n'
            'Errors: ${data['errorsCount']}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduler manual run fini.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = 'Erreur: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur scheduler: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _box({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Commission Scheduler',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _box(
            child: const Text(
              'Chak dimanch a 11:00 PM, scheduler la ap kouri komisyon yo otomatikman. '
              'Ou ka teste li manylman anba a.',
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
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _busy ? null : _runNow,
              icon: const Icon(Icons.schedule_outlined),
              label: Text(
                _busy ? 'Ap kouri...' : 'Run Sunday Scheduler Now',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _box(
            child: SelectableText(
              _result,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}