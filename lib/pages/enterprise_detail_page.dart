import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EnterpriseDetailPage extends StatefulWidget {
  final String enterpriseId;

  const EnterpriseDetailPage({
    super.key,
    required this.enterpriseId,
  });

  @override
  State<EnterpriseDetailPage> createState() => _EnterpriseDetailPageState();
}

class _EnterpriseDetailPageState extends State<EnterpriseDetailPage> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _isActive = true;

  DocumentReference<Map<String, dynamic>> get _ref =>
      FirebaseFirestore.instance.collection('enterprises').doc(widget.enterpriseId);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  Future<void> _load() async {
    try {
      final snap = await _ref.get();
      final data = snap.data() ?? <String, dynamic>{};

      _nameCtrl.text =
          (data['name'] ?? data['enterpriseName'] ?? widget.enterpriseId).toString();
      _balanceCtrl.text = _asDouble(data['balance']).toStringAsFixed(2);
      _isActive = data['isActive'] is bool ? data['isActive'] as bool : true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur load enterprise: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enterprise name pa dwe vid.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _ref.set({
        'name': name,
        'enterpriseName': name,
        'balance': balance,
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enterprise update avk siks.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur save enterprise: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _toggleActive(bool value) async {
    setState(() => _isActive = value);
    try {
      await _ref.set({
        'isActive': value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Enterprise re-aktive.'
                : 'Enterprise sispann.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isActive = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur toggle active: $e')),
      );
    }
  }

  Widget _infoBox(String title, String value) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Enterprise Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Enterprise: ${widget.enterpriseId}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _infoBox('Enterprise ID', widget.enterpriseId),
                _infoBox('Status', _isActive ? 'ACTIVE' : 'SUSPENDED'),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Enterprise Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Balance',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isActive,
              onChanged: _toggleActive,
              title: const Text('Enterprise Active'),
              subtitle: Text(
                _isActive
                    ? 'Enterprise sa a aktif'
                    : 'Enterprise sa a sispann',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? 'Saving...' : 'Save Enterprise'),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Nt:\n'
                    '- isActive=false vle di enterprise la sispann.\n'
                    '- balance la ka modifye manylman isit la.\n'
                    '- name ak enterpriseName ap rete menm val.',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}