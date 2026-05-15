import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EnterpriseSettingsPage extends StatefulWidget {
  const EnterpriseSettingsPage({super.key});

  @override
  State<EnterpriseSettingsPage> createState() => _EnterpriseSettingsPageState();
}

class _EnterpriseSettingsPageState extends State<EnterpriseSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String _enterpriseId = '';
  String _enterpriseName = '';

  @override
  void initState() {
    super.initState();
    _loadEnterprise();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _currencyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _text(dynamic value, [String fallback = '']) {
    final s = (value ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  InputDecoration _decor({
    required String label,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF111827), width: 1.3),
      ),
    );
  }

  Future<void> _loadEnterprise() async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) {
        throw Exception('User pa konekte.');
      }

      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .get();

      final userData = userSnap.data() ?? <String, dynamic>{};
      final enterpriseId = _text(userData['enterpriseId']);
      final enterpriseName = _text(userData['enterpriseName'], 'VOUPVAPCASH');

      if (enterpriseId.isEmpty) {
        throw Exception('enterpriseId pa disponib sou user la.');
      }

      final entSnap = await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(enterpriseId)
          .get();

      final entData = entSnap.data() ?? <String, dynamic>{};

      _enterpriseId = enterpriseId;
      _enterpriseName = enterpriseName;

      _nameCtrl.text = _text(entData['name'], enterpriseName);
      _phoneCtrl.text = _text(entData['phone']);
      _emailCtrl.text = _text(entData['email']);
      _addressCtrl.text = _text(entData['address']);
      _currencyCtrl.text = _text(entData['currency'], 'USD');
      _noteCtrl.text = _text(entData['notes']);

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan loading enterprise la: $e')),
      );
    }
  }

  Future<void> _saveEnterprise() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_enterpriseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('enterpriseId pa disponib.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final payload = {
        'enterpriseId': _enterpriseId,
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'currency': _currencyCtrl.text.trim().isEmpty
            ? 'USD'
            : _currencyCtrl.text.trim().toUpperCase(),
        'notes': _noteCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('enterprises')
          .doc(_enterpriseId)
          .set(payload, SetOptions(merge: true));

      final users = await FirebaseFirestore.instance
          .collection('users')
          .where('enterpriseId', isEqualTo: _enterpriseId)
          .get();

      for (final doc in users.docs) {
        await doc.reference.update({
          'enterpriseName': _nameCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      final enterpriseUsers = await FirebaseFirestore.instance
          .collection('enterprise_users')
          .where('enterpriseId', isEqualTo: _enterpriseId)
          .get();

      for (final doc in enterpriseUsers.docs) {
        await doc.reference.update({
          'enterpriseName': _nameCtrl.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      setState(() {
        _enterpriseName = _nameCtrl.text.trim();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enterprise settings yo sove avk siks.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pandan save enterprise la: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
              Icons.apartment_outlined,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        title: const Text(
          'Enterprise Settings',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _headerCard(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Enfmasyon enterprise',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: _decor(
                            label: 'Non enterprise / company',
                            icon: Icons.business_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Mete non enterprise la.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: _decor(
                            label: 'Telefn enterprise',
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _decor(
                            label: 'Iml enterprise',
                            icon: Icons.email_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _addressCtrl,
                          maxLines: 2,
                          decoration: _decor(
                            label: 'Adrs enterprise',
                            icon: Icons.location_on_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _currencyCtrl,
                          decoration: _decor(
                            label: 'Monnen default (USD, HTG, DOP...)',
                            icon: Icons.attach_money_outlined,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _noteCtrl,
                          maxLines: 4,
                          decoration: _decor(
                            label: 'Nt enterprise',
                            icon: Icons.sticky_note_2_outlined,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 54,
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF111827),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: _saving ? null : _saveEnterprise,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(
                              _saving ? 'Ap sove...' : 'Sove Settings',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}