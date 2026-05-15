import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

class NewTransactionPage extends StatefulWidget {
  const NewTransactionPage({super.key});

  @override
  State<NewTransactionPage> createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {
  final _customerPhoneCtrl = TextEditingController();
  final _beneficiaryPhoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _saving = false;

  static const String enterpriseId = "ENT-001";
  static const String enterpriseName = "VOUPVAPCASH";

  double _asDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  Future<void> _submit() async {
    final customerPhone = _customerPhoneCtrl.text.trim();
    final beneficiaryPhone = _beneficiaryPhoneCtrl.text.trim();
    final amount = _asDouble(_amountCtrl.text);
    final note = _noteCtrl.text.trim();

    if (customerPhone.isEmpty || beneficiaryPhone.isEmpty || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ranpli Customer Phone, Beneficiary Phone, ak Amount."),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
            "Pa gen user konekte. Login ak owner/admin/agent ki deja egziste.");
      }

      if (user.isAnonymous) {
        throw Exception(
            "Current user la anonymous. Tanpri konekte ak owner/admin/agent reyÃ¨l la.");
      }

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final userData = userDoc.data();
      if (userData == null) {
        throw Exception(
            "users/${user.uid} pa egziste. Current auth user la pa matche ak user ki nan Firestore.");
      }

      final role = (userData["role"] ?? "").toString().trim().toLowerCase();
      final savedEnterpriseId =
          (userData["enterpriseId"] ?? enterpriseId).toString();
      final savedEnterpriseName =
          (userData["enterpriseName"] ?? enterpriseName).toString();
      final staffName =
          (userData["displayName"] ?? userData["fullName"] ?? "Staff")
              .toString();

      if (role.isEmpty) {
        throw Exception("Role pa defini nan users/${user.uid}");
      }

      final docRef =
          FirebaseFirestore.instance.collection("transactions").doc();
      final txId = "TXN_${DateTime.now().millisecondsSinceEpoch}";

      await docRef.set({
        "txId": txId,
        "transactionId": txId,
        "enterpriseId": savedEnterpriseId,
        "enterpriseName": savedEnterpriseName,
        "staffUid": user.uid,
        "staffName": staffName,
        "staffRole": role,
        "customerPhone": customerPhone,
        "beneficiaryPhone": beneficiaryPhone,
        "paymentAmount": amount,
        "transferAmount": amount,
        "paymentCurrency": "USD",
        "transferCurrency": "HTG",
        "serviceName": "MonCash",
        "category": "transfer",
        "status": "delivered",
        "paymentStatus": "paid",
        "commissionAgent": 5,
        "commissionOwner": 3,
        "note": note,
        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Transaction kreye: $txId")),
      );

      _customerPhoneCtrl.clear();
      _beneficiaryPhoneCtrl.clear();
      _amountCtrl.clear();
      _noteCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("ErÃ¨: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _customerPhoneCtrl.dispose();
    _beneficiaryPhoneCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Transaction"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _customerPhoneCtrl,
            decoration: const InputDecoration(
              labelText: "Customer Phone",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _beneficiaryPhoneCtrl,
            decoration: const InputDecoration(
              labelText: "Beneficiary Phone",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Amount",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(
              labelText: "Note",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? "Ap kreye..." : "Create Transaction"),
          ),
        ],
      ),
    );
  }
}
