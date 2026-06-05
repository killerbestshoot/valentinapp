import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';

class CreateTransactionPage extends StatefulWidget {
  const CreateTransactionPage({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  static const _ink = Color(0xFF172116);
  static const _muted = Color(0xFF667365);
  static const _surface = Color(0xFFF4F8F1);
  static const _brand = Color(0xFF123D2B);

  final _formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  String serviceName = 'MonCash';
  String paymentCurrency = 'MXN';
  bool loading = false;

  final services = const ['MonCash', 'NatCash', 'Minit Haiti'];
  final currencies = const ['MXN', 'USD', 'DOP', 'CLP', 'BRL', 'HTG'];

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    amountCtrl.dispose();
    super.dispose();
  }

  double _num(String v) => double.tryParse(v.replaceAll(',', '.').trim()) ?? 0;

  Future<void> save() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final amount = _num(amountCtrl.text);

    setState(() => loading = true);

    try {
      final txId = AppIds.transaction(
        seed: '$serviceName:$phone:${DateTime.now().toIso8601String()}',
      );

      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(txId)
          .set({
        'txId': txId,
        'transactionId': txId,
        'serviceName': serviceName,
        'customerName': name,
        'customerPhone': phone,
        'paymentAmount': amount,
        'paymentCurrency': paymentCurrency,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Transaction anrejistre'),
          content: SelectableText('ID: $txId'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      nameCtrl.clear();
      phoneCtrl.clear();
      amountCtrl.clear();
    } catch (e) {
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Erreur'),
          content: SelectableText(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = amountCtrl.text.trim();

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        foregroundColor: _ink,
        centerTitle: true,
        title: const Text(
          'Nouvo transaction',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;

            return Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  isWide ? 32 : 16,
                  12,
                  isWide ? 32 : 16,
                  32,
                ),
                children: [
                  _HeroBand(isWide: isWide),
                  const SizedBox(height: 18),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: isWide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 7, child: _buildFormCard()),
                                const SizedBox(width: 18),
                                Expanded(
                                  flex: 3,
                                  child: _SummaryCard(
                                    service: serviceName,
                                    customerName: nameCtrl.text,
                                    phone: phoneCtrl.text,
                                    amount: amount,
                                    currency: paymentCurrency,
                                    loading: loading,
                                    onSave: save,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _SummaryCard(
                                  service: serviceName,
                                  customerName: nameCtrl.text,
                                  phone: phoneCtrl.text,
                                  amount: amount,
                                  currency: paymentCurrency,
                                  loading: loading,
                                  onSave: save,
                                ),
                                const SizedBox(height: 18),
                                _buildFormCard(),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note_outlined, color: _brand),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Detay transaction',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: serviceName,
            decoration: _inputDecoration(
              label: 'Service',
              icon: Icons.storefront_outlined,
            ),
            items: services
                .map((service) => DropdownMenuItem(
                      value: service,
                      child: Text(service),
                    ))
                .toList(),
            onChanged: loading
                ? null
                : (v) => setState(() => serviceName = v ?? 'MonCash'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: nameCtrl,
            enabled: !loading,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Non kliyan',
              icon: Icons.person_outline,
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Non kliyan obligatwa.';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: phoneCtrl,
            enabled: !loading,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: _inputDecoration(
              label: 'Telefòn',
              icon: Icons.phone_outlined,
            ),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) return 'Telefòn obligatwa.';
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: amountCtrl,
                  enabled: !loading,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: _inputDecoration(
                    label: 'Montan',
                    icon: Icons.payments_outlined,
                  ),
                  validator: (value) {
                    if (_num(value ?? '') <= 0) {
                      return 'Mete yon montan ki valid.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: paymentCurrency,
                  decoration: _inputDecoration(
                    label: 'Deviz',
                    icon: Icons.attach_money,
                  ),
                  items: currencies
                      .map((currency) => DropdownMenuItem(
                            value: currency,
                            child: Text(currency),
                          ))
                      .toList(),
                  onChanged: loading
                      ? null
                      : (v) => setState(() => paymentCurrency = v ?? 'MXN'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: loading ? null : save,
            style: FilledButton.styleFrom(
              backgroundColor: _brand,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label:
                Text(loading ? 'Ap anrejistre...' : 'Anrejistre transaction'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF9FCF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDDE8D8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFDDE8D8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _brand, width: 1.5),
      ),
    );
  }
}

class _HeroBand extends StatelessWidget {
  const _HeroBand({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Container(
          padding: EdgeInsets.all(isWide ? 28 : 20),
          decoration: BoxDecoration(
            color: _CreateTransactionPageState._brand,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_card_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kreye yon transaction',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ranpli enfòmasyon kliyan an, verifye rezime a, epi anrejistre.',
                      style: TextStyle(
                        color: Color(0xFFDDE8D8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.service,
    required this.customerName,
    required this.phone,
    required this.amount,
    required this.currency,
    required this.loading,
    required this.onSave,
  });

  final String service;
  final String customerName;
  final String phone;
  final String amount;
  final String currency;
  final bool loading;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final displayAmount = amount.trim().isEmpty ? '0' : amount.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Rezime',
            style: TextStyle(
              color: _CreateTransactionPageState._ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F8EE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Montan',
                  style: TextStyle(
                    color: _CreateTransactionPageState._muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$displayAmount $currency',
                  style: const TextStyle(
                    color: _CreateTransactionPageState._ink,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SummaryLine(label: 'Service', value: service),
          _SummaryLine(
            label: 'Kliyan',
            value: customerName.trim().isEmpty
                ? 'Non pa antre'
                : customerName.trim(),
          ),
          _SummaryLine(
            label: 'Telefòn',
            value: phone.trim().isEmpty ? 'Telefòn pa antre' : phone.trim(),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: loading ? null : onSave,
            style: OutlinedButton.styleFrom(
              foregroundColor: _CreateTransactionPageState._brand,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Verifye & save'),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _CreateTransactionPageState._muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: _CreateTransactionPageState._ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
