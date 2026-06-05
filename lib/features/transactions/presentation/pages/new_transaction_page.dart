import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_brand.dart';
import '../../../../core/session/app_session.dart';
import 'package:mon_premye_app/services/shared/app_ids.dart';

class NewTransactionPage extends StatefulWidget {
  const NewTransactionPage({super.key});

  @override
  State<NewTransactionPage> createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _clientController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  String _selectedCountry = 'Ayiti (+509)';
  String _selectedService = AppBrand.supportedServices.first;
  bool _saving = false;

  List<String> get _countries {
    return AppBrand.supportedCountries
        .map((e) => '${e['name']} (${e['code']})')
        .toList();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      final txId = AppIds.transaction(
        seed:
            '${AppSession.enterpriseId}:${AppSession.currentUserId}:${DateTime.now().toIso8601String()}',
      );

      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(txId)
          .set({
        'txId': txId,
        'transactionId': txId,
        'clientName': _clientController.text.trim(),
        'phone': _phoneController.text.trim(),
        'amount': amount,
        'country': _selectedCountry,
        'service': _selectedService,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'agentId': AppSession.currentUserId,
        'agentName': AppSession.currentUserName,
        'enterpriseId': AppSession.enterpriseId,
        'enterpriseName': AppSession.enterpriseName.trim().isEmpty
            ? AppBrand.defaultEnterpriseName
            : AppSession.enterpriseName,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tranzaksyon anrejistre')),
      );

      _clientController.clear();
      _phoneController.clear();
      _amountController.clear();

      setState(() {
        _selectedCountry = 'Ayiti (+509)';
        _selectedService = AppBrand.supportedServices.first;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Er: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enterpriseName = AppSession.enterpriseName.trim().isEmpty
        ? AppBrand.defaultEnterpriseName
        : AppSession.enterpriseName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvo tranzaksyon'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Antrepriz: $enterpriseName',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _clientController,
                decoration: const InputDecoration(
                  labelText: 'Non kliyan',
                  border: UnderlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mete non kliyan an';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefn',
                  border: UnderlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mete telefn nan';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montan',
                  border: UnderlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Mete montan an';
                  }
                  if (double.tryParse(v.trim()) == null) {
                    return 'Montan an pa valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'Peyi',
                  border: UnderlineInputBorder(),
                ),
                items: _countries
                    .map(
                      (country) => DropdownMenuItem(
                        value: country,
                        child: Text(country),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCountry = value);
                  }
                },
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                initialValue: _selectedService,
                decoration: const InputDecoration(
                  labelText: 'Svis',
                  border: UnderlineInputBorder(),
                ),
                items: AppBrand.supportedServices
                    .map(
                      (service) => DropdownMenuItem(
                        value: service,
                        child: Text(service),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedService = value);
                  }
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveTransaction,
                  child: Text(
                    _saving ? 'Ap anrejistre...' : 'Anrejistre tranzaksyon',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
