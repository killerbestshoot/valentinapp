import 'package:flutter/material.dart';
import 'package:mon_premye_app/services/wallet/wallet_topup_request_service.dart';

class WalletTopupRequestPage extends StatefulWidget {
  const WalletTopupRequestPage({super.key});

  @override
  State<WalletTopupRequestPage> createState() => _WalletTopupRequestPageState();
}

class _WalletTopupRequestPageState extends State<WalletTopupRequestPage> {
  final TextEditingController searchController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  bool loading = false;
  Map<String, dynamic>? selectedStaff;
  Map<String, dynamic>? myProfile;

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  Future<void> _loadProfile() async {
    try {
      final profile = await WalletTopupRequestService.getMyProfile();
      if (!mounted) return;
      setState(() {
        myProfile = profile;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER PROFILE: $e')),
      );
    }
  }

  Future<void> _searchStaff() async {
    final q = searchController.text.trim();

    setState(() {
      loading = true;
      selectedStaff = null;
    });

    try {
      final found = await WalletTopupRequestService.findStaffInEnterprise(q);
      if (!mounted) return;
      setState(() {
        selectedStaff = found;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER SEARCH: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _sendRequest() async {
    if (selectedStaff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chwazi staff an premye')),
      );
      return;
    }

    final amount = double.tryParse(amountController.text.trim()) ?? 0;
    final note = noteController.text.trim();

    setState(() {
      loading = true;
    });

    try {
      await WalletTopupRequestService.createTopupRequest(
        targetStaff: selectedStaff!,
        amount: amount,
        note: note,
      );

      amountController.clear();
      noteController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wallet topup request voye')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER REQUEST: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    searchController.dispose();
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = (myProfile?['role'] ?? '').toString();
    final isAllowed =
        role == 'owner' || role == 'administrator' || role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet Topup Request'),
      ),
      body: myProfile == null
          ? const Center(child: CircularProgressIndicator())
          : !isAllowed
              ? const Center(
                  child: Text('Se owner/admin slman ki ka f topup request'),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'ROLE: ${(myProfile?['role'] ?? '').toString()}'),
                            Text(
                                'ENTERPRISE: ${(myProfile?['enterpriseName'] ?? '').toString()}'),
                            Text(
                                'ENTERPRISE ID: ${(myProfile?['enterpriseId'] ?? '').toString()}'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        labelText: 'Chche staff pa email / uid / non',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: loading ? null : _searchStaff,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child:
                              Text(loading ? 'Tanpri tann...' : 'Search Staff'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (selectedStaff != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'STAFF FOUND',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _line('UID',
                                  (selectedStaff!['uid'] ?? '').toString()),
                              _line(
                                  'Name',
                                  (selectedStaff!['displayName'] ?? '')
                                      .toString()),
                              _line('Email',
                                  (selectedStaff!['email'] ?? '').toString()),
                              _line('Role',
                                  (selectedStaff!['role'] ?? '').toString()),
                              _line(
                                'Wallet',
                                '${_fmtMoney(_toDouble(selectedStaff!['walletBalance']))} USD',
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (selectedStaff != null) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Topup Amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Note',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: loading ? null : _sendRequest,
                          icon: const Icon(Icons.send),
                          label: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              loading ? 'Tanpri tann...' : 'Send Topup Request',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
