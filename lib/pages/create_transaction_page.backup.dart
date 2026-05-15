import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _customerPhoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _directionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _loading = false;

  String _service = 'topup';
  String _countryName = 'Haiti';
  String _countryCode = '+509';
  String _currency = 'HTG';

  bool get _isTopup => _service == 'topup';

  final List<Map<String, String>> _services = const [
    {'id': 'topup', 'name': 'Minit / TopUp'},
    {'id': 'moncash', 'name': 'MonCash'},
    {'id': 'natcash', 'name': 'NatCash'},
    {'id': 'western_union', 'name': 'Western Union'},
    {'id': 'cam', 'name': 'CAM Transfer'},
  ];

  final List<Map<String, String>> _countries = const [
    {'name': 'Haiti', 'code': '+509', 'currency': 'HTG'},
    {'name': 'Mexico', 'code': '+52', 'currency': 'MXN'},
    {'name': 'Brazil', 'code': '+55', 'currency': 'BRL'},
    {'name': 'Republique Dominicaine', 'code': '+1', 'currency': 'DOP'},
    {'name': 'Chile', 'code': '+56', 'currency': 'CLP'},
    {'name': 'United States', 'code': '+1', 'currency': 'USD'},
  ];

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _customerPhoneCtrl.dispose();
    _amountCtrl.dispose();
    _directionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Chan sa obligatwa';
    return null;
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      prefixText: prefixText,
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ou pa konekte')),
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kantite kob la pa valid')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      final userData = userDoc.data() ?? {};
      final enterpriseId = (userData['enterpriseId'] ?? '').toString();
      final staffName = (userData['name'] ?? user.email ?? '').toString();
      final staffRole = (userData['role'] ?? '').toString();

      if (enterpriseId.isEmpty) {
        throw Exception('enterpriseId manke sou users/${user.uid}');
      }

      final serviceName = _services.firstWhere((s) => s['id'] == _service)['name'].toString();
      final customerPhone = '$_countryCode ${_customerPhoneCtrl.text.trim()}';

      await FirebaseFirestore.instance.collection('transactions').add({
        'enterpriseId': enterpriseId,
        'staffUid': user.uid,
        'staffName': staffName,
        'staffRole': staffRole,

        'serviceId': _service,
        'serviceName': serviceName,
        'category': _isTopup ? 'topup' : 'transfer',

        'countryName': _countryName,
        'countryCode': _countryCode,

        'customerName': _isTopup ? '' : _customerNameCtrl.text.trim(),
        'customerPhone': customerPhone,

        'paymentAmount': amount,
        'paymentCurrency': _currency,
        'transferAmount': amount,
        'transferCurrency': _currency,

        'direction': _isTopup ? _countryName : _directionCtrl.text.trim(),
        'receiverLocation': _isTopup ? _countryName : _directionCtrl.text.trim(),
        'destination': _isTopup ? _countryName : _directionCtrl.text.trim(),

        'notes': _noteCtrl.text.trim(),

        'status': 'delivered',
        'paymentStatus': 'paid',
        'commissionApplied': false,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'paymentDate': FieldValue.serverTimestamp(),
        'depositDate': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tranzaksyon an kreye')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ere: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kreye Tranzaksyon'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _service,
                  decoration: _decoration(label: 'Sevis', icon: Icons.settings),
                  items: _services.map((s) {
                    return DropdownMenuItem<String>(
                      value: s['id'],
                      child: Text(s['name']!),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() {
                            _service = v;
                          });
                        },
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: _countryName,
                  decoration: _decoration(label: 'Peyi / Kod peyi', icon: Icons.flag),
                  items: _countries.map((c) {
                    return DropdownMenuItem<String>(
                      value: c['name'],
                      child: Text('${c['name']} (${c['code']})'),
                    );
                  }).toList(),
                  onChanged: _loading
                      ? null
                      : (v) {
                          if (v == null) return;
                          final c = _countries.firstWhere((x) => x['name'] == v);
                          setState(() {
                            _countryName = c['name']!;
                            _countryCode = c['code']!;
                            _currency = c['currency']!;
                          });
                        },
                ),
                const SizedBox(height: 12),

                if (!_isTopup) ...[
                  TextFormField(
                    controller: _customerNameCtrl,
                    decoration: _decoration(label: 'Non kliyan', icon: Icons.person),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _customerPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: _decoration(
                    label: 'Nimewo kliyan',
                    icon: Icons.phone,
                    prefixText: '$_countryCode ',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _decoration(
                    label: 'Kantite kob ($_currency)',
                    icon: Icons.attach_money,
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 12),

                if (!_isTopup) ...[
                  TextFormField(
                    controller: _directionCtrl,
                    decoration: _decoration(
                      label: 'Direksyon / kote kob la prale',
                      icon: Icons.place,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                ],

                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  decoration: _decoration(label: 'Not', icon: Icons.note),
                ),
                const SizedBox(height: 18),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_loading ? 'Ap kreye...' : 'Kreye Tranzaksyon'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NewTransactionPage extends StatelessWidget {
  const NewTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateTransactionPage();
  }
}

class DynamicTransactionPage extends StatelessWidget {
  final String? serviceId;
  final Map<String, dynamic>? serviceData;

  const DynamicTransactionPage({
    super.key,
    this.serviceId,
    this.serviceData,
  });

  @override
  Widget build(BuildContext context) {
    return const CreateTransactionPage();
  }
}

class RunCreateTransactionPage extends StatelessWidget {
  const RunCreateTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateTransactionPage();
  }
}