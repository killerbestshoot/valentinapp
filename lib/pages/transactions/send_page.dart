import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mon_premye_app/services/commission/commission_service.dart';

import 'package:mon_premye_app/services/shared/app_ids.dart';
import 'package:mon_premye_app/services/clients/client_risk_service.dart';
import 'package:mon_premye_app/services/enterprise/enterprise_status_service.dart';
import 'package:mon_premye_app/services/users/user_status_service.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

class SendPage extends StatefulWidget {
  const SendPage({super.key});

  @override
  State<SendPage> createState() => _SendPageState();
}

class _SendPageState extends State<SendPage> {
  final _beneficiaryPhoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _loading = false;

  String _beneficiaryRisk = 'normal';
  String _beneficiaryRiskNote = '';

  @override
  void dispose() {
    _beneficiaryPhoneCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double _asDouble(String v) => double.tryParse(v.trim()) ?? 0;

  Future<Map<String, dynamic>> _loadUserDoc(String uid) async {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    return doc.data() ?? <String, dynamic>{};
  }

  Color _riskColor(String status) {
    switch (status) {
      case 'blacklist':
        return Colors.red;
      case 'watchlist':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  Future<void> _refreshRisk() async {
    final beneficiaryPhone = _beneficiaryPhoneCtrl.text.trim();
    final beneficiary = await ClientRiskService.getClientFlag(beneficiaryPhone);

    if (!mounted) return;
    setState(() {
      _beneficiaryRisk = (beneficiary['status'] ?? 'normal').toString();
      _beneficiaryRiskNote = (beneficiary['note'] ?? '').toString();
    });
  }

  Future<void> _send() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final amount = _asDouble(_amountCtrl.text);
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mete yon amount ki valid.')),
      );
      return;
    }

    final beneficiaryPhone = _beneficiaryPhoneCtrl.text.trim();
    final beneficiaryFlag =
        await ClientRiskService.getClientFlag(beneficiaryPhone);
    final beneficiaryStatus =
        (beneficiaryFlag['status'] ?? 'normal').toString();
    if (!mounted) return;

    if (beneficiaryStatus == 'blacklist') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Send bloke: beneficiary nan blacklist.')),
      );
      return;
    }

    if (beneficiaryStatus == 'watchlist') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atansyon: beneficiary sou watchlist.')),
      );
    }

    setState(() => _loading = true);

    try {
      final userData = await _loadUserDoc(user.uid);
      final role = (userData['role'] ?? '').toString().trim().toLowerCase();

      final userActive = await UserStatusService.isUserActive(user.uid);
      if (!userActive) {
        throw Exception('Kont sa a sispann. Ou pa ka f send.');
      }
      if (role != 'agent') {
        throw Exception('Se agent slman ki ka f send.');
      }

      final enterpriseId = (userData['enterpriseId'] ?? '').toString();
      final enterpriseName =
          (userData['enterpriseName'] ?? 'VOUPVAPCASH').toString();
      final staffName =
          (userData['displayName'] ?? userData['fullName'] ?? 'Agent')
              .toString();

      final enterpriseActive =
          await EnterpriseStatusService.isEnterpriseActive(enterpriseId);
      if (!enterpriseActive) {
        throw Exception('Enterprise sa a sispann. Ou pa ka f send.');
      }

      final now = DateTime.now();
      final txId = AppIds.send(
        seed:
            '$enterpriseId:${user.uid}:$beneficiaryPhone:${now.toIso8601String()}',
      );
      await FirebaseFirestore.instance
          .collection('transactions')
          .doc(txId)
          .set({
        'txId': txId,
        'transactionId': txId,
        'enterpriseId': enterpriseId,
        'staffUid': user.uid,
        'enterpriseName': enterpriseName,
        'staffName': staffName,
        'serviceName': 'send',
        'category': 'transfer',
        'customerPhone': '',
        'beneficiaryPhone': beneficiaryPhone,
        'note': _noteCtrl.text.trim(),
        'paymentAmount': amount,
        'paymentCurrency': 'USD',
        'transferAmount': amount,
        'transferCurrency': 'USD',
        'status': 'delivered',
        'paymentStatus': 'paid',
        'commissionAgent': 0,
        'commissionOwner': 0,
        'commissionApplied': false,
        'beneficiaryRiskStatus': beneficiaryStatus,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
      await CommissionService.applyCommission(txId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Send anrejistre: $txId')),
      );

      _beneficiaryPhoneCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
      setState(() {
        _beneficiaryRisk = 'normal';
        _beneficiaryRiskNote = '';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration deco(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: DashboardColors.brand, width: 1.4),
      ),
    );
  }

  Widget riskBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _riskColor(_beneficiaryRisk).withValues(alpha: 0.08),
        border: Border.all(color: _riskColor(_beneficiaryRisk)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _beneficiaryRiskNote.isEmpty
            ? 'Beneficiary Risk: $_beneficiaryRisk'
            : 'Beneficiary Risk: $_beneficiaryRisk | Note: $_beneficiaryRiskNote',
        style: TextStyle(
          color: _riskColor(_beneficiaryRisk),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPage(
      title: 'Send transfer',
      maxWidth: 760,
      children: [
        const DashboardHero(
          icon: Icons.send_outlined,
          title: 'Send money',
          subtitle:
              'Create a secure agent transfer and apply commission rules.',
        ),
        const SizedBox(height: 18),
        DashboardPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _beneficiaryPhoneCtrl,
                decoration: deco('Beneficiary Phone'),
                onChanged: (_) => _refreshRisk(),
              ),
              const SizedBox(height: 8),
              riskBox(),
              const SizedBox(height: 12),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: deco('Amount'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: deco('Note'),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _send,
                  child: Text(_loading ? 'Sending...' : 'Send transfer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
