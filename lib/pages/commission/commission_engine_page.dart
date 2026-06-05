import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/commission/commission_service.dart';

class CommissionEnginePage extends StatefulWidget {
  const CommissionEnginePage({super.key});

  @override
  State<CommissionEnginePage> createState() => _CommissionEnginePageState();
}

class _CommissionEnginePageState extends State<CommissionEnginePage> {
  bool _busy = false;
  String _enterpriseId = '';
  String _enterpriseName = '';
  String _role = '';
  String _result = 'Pa gen run ank.';

  String _text(dynamic value, [String fallback = '']) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User pa konekte.');
      }

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snap.data() ?? <String, dynamic>{};

      if (!mounted) return;
      setState(() {
        _enterpriseId = _text(data['enterpriseId']);
        _enterpriseName = _text(data['enterpriseName'], 'VOUPVAPCASH');
        _role = _text(data['role']);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur profil: $e')),
      );
    }
  }

  Future<void> _runNow() async {
    if (_busy) return;

    if (_enterpriseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('enterpriseId pa disponib.')),
      );
      return;
    }

    if (_role != 'owner' && _role != 'administrator') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Se owner/admin slman ki ka lanse commission engine lan.'),
        ),
      );
      return;
    }

    setState(() => _busy = true);

    try {
      final result = await CommissionService.runForEnterprise(_enterpriseId);

      if (!mounted) return;
      setState(() {
        _result = 'Enterprise: $_enterpriseName\n'
            'Scanned: ${result['total']}\n'
            'Applied: ${result['applied']}\n'
            'Skipped: ${result['skipped']}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commission engine fini kouri avk siks.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = 'Erreur: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur commission engine: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_graph_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _enterpriseName.isEmpty ? 'Enterprise' : _enterpriseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _enterpriseId.isEmpty ? 'ENT-ID' : _enterpriseId,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _box({
    required Widget child,
  }) {
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
          'Commission Engine',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _headerCard(),
          const SizedBox(height: 16),
          _box(
            child: const Text(
              'Page sa a ap aplike komisyon sou tranzaksyon delivered yo. '
              'Li pa double apply si commissionApplied deja true.',
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
              icon: const Icon(Icons.play_arrow_outlined),
              label: Text(
                _busy ? 'Ap kouri...' : 'Run Commission Engine Now',
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
          const SizedBox(height: 16),
          _box(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _enterpriseId.isEmpty
                  ? FirebaseFirestore.instance
                      .collection('commission_runs')
                      .limit(0)
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('commission_runs')
                      .where('enterpriseId', isEqualTo: _enterpriseId)
                      .limit(20)
                      .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = [...(snap.data?.docs ?? [])];
                docs.sort((a, b) {
                  final da = a.data()['createdAt'];
                  final db = b.data()['createdAt'];
                  final ta = da is Timestamp
                      ? da.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(0);
                  final tb = db is Timestamp
                      ? db.toDate()
                      : DateTime.fromMillisecondsSinceEpoch(0);
                  return tb.compareTo(ta);
                });

                if (docs.isEmpty) {
                  return const Text(
                    'Pa gen commission run ank.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dnye Commission Runs',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...docs.take(8).map((d) {
                      final m = d.data();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Run ID: ${m['runId'] ?? d.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('Scanned: ${m['scanned'] ?? 0}'),
                            Text('Applied: ${m['applied'] ?? 0}'),
                            Text('Skipped: ${m['skipped'] ?? 0}'),
                          ],
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
