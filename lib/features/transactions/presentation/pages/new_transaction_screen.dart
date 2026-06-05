import 'package:flutter/material.dart';

import '../../domain/create_transaction_use_case.dart';

class NewTransactionScreen extends StatefulWidget {
  final String? initialService;

  const NewTransactionScreen({
    super.key,
    this.initialService,
  });

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _countryController = TextEditingController();
  final _serviceController = TextEditingController();
  final CreateTransactionUseCase _createUseCase = CreateTransactionUseCase();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialService != null) {
      _serviceController.text = widget.initialService!;
    }
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _countryController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final clientName = _clientNameController.text.trim();
    final phone = _phoneController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final country = _countryController.text.trim();
    final service = _serviceController.text.trim();

    if (service.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tanpri antre non sèvis la.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _createUseCase.execute(
        clientName: clientName,
        phone: phone,
        amount: amount,
        country: country,
        service: service,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tranzaksyon an kreye avèk siksè.')),
      );
      _formKey.currentState?.reset();
      _serviceController.text = widget.initialService ?? '';
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Echèk kreye tranzaksyon: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Transaction')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _clientNameController,
                decoration: const InputDecoration(labelText: 'Client Name'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tanpri antre non kliyan an.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Telephone'),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tanpri antre nimewo telefòn lan.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount <= 0) {
                    return 'Tanpri antre yon valè pozitif.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryController,
                decoration: const InputDecoration(labelText: 'Country'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tanpri antre non peyi a.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _serviceController,
                decoration: const InputDecoration(labelText: 'Service'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tanpri antre non sèvis la.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Saving...' : 'Create Transaction'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
