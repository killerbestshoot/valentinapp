import "package:cloud_firestore/cloud_firestore.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:mon_premye_app/services/commission_service.dart";

class RunCommissionPage extends StatefulWidget {
  const RunCommissionPage({super.key});

  @override
  State<RunCommissionPage> createState() => _RunCommissionPageState();
}

class _RunCommissionPageState extends State<RunCommissionPage> {
  final TextEditingController _txIdCtrl = TextEditingController();
  bool _loading = false;
  String _status = "";

  Future<Map<String, dynamic>?> _getCurrentUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .get();

    return doc.data();
  }

  Future<void> _applyNow() async {
    final value = _txIdCtrl.text.trim();

    if (value.isEmpty) {
      setState(() {
        _status = "Mete transactionId oswa txId. Pa mete UID user la.";
      });
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _status = "Pa gen user konekte.";
      });
      return;
    }

    if (currentUser.isAnonymous) {
      setState(() {
        _status = "Current user la anonymous. Konekte ak owner/admin reyèl la.";
      });
      return;
    }

    setState(() {
      _loading = true;
      _status = "Ap trete commission lan...";
    });

    try {
      await CommissionService.applyCommission(txId: value);

      if (!mounted) return;
      setState(() {
        _status = "Commission aplike avèk siksè pou: $value";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Commission aplike.")),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = "Function error: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Widget _recentTxList() {
    final stream = FirebaseFirestore.instance
        .collection("transactions")
        .orderBy("createdAt", descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text("Erè transactions: ${snap.error}");
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Text("Pa gen transactions pou chwazi.");
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((d) {
            final data = d.data();
            final txId =
                (data["transactionId"] ?? data["txId"] ?? d.id).toString();
            final staffRole = (data["staffRole"] ?? "-").toString();
            final serviceName = (data["serviceName"] ?? "-").toString();
            final paymentAmount = (data["paymentAmount"] ?? 0).toString();
            final commissionApplied = data["commissionApplied"] == true ||
                data["commissionsApplied"] == true;

            return Card(
              child: ListTile(
                title: Text(txId),
                subtitle: Text(
                  "service: $serviceName | role: $staffRole | amount: $paymentAmount | applied: $commissionApplied",
                ),
                trailing: const Icon(Icons.content_paste_go_outlined),
                onTap: () {
                  setState(() {
                    _txIdCtrl.text = txId;
                    _status = "Transaction chwazi: $txId";
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  void dispose() {
    _txIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Run Commission"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<Map<String, dynamic>?>(
            future: _getCurrentUserDoc(),
            builder: (context, snap) {
              final data = snap.data;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "SESSION INFO",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text("auth uid: ${currentUser?.uid ?? '-'}"),
                      Text("anonymous: ${currentUser?.isAnonymous ?? '-'}"),
                      Text(
                          "users/{uid} role: ${(data?["role"] ?? "pa jwenn").toString()}"),
                      Text(
                          "enterpriseId: ${(data?["enterpriseId"] ?? "-").toString()}"),
                      const SizedBox(height: 8),
                      const Text(
                        "ATANSYON: isit la ou dwe mete transactionId oswa txId. Pa mete UID user la.",
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _txIdCtrl,
            decoration: const InputDecoration(
              labelText: "Transaction ID",
              border: OutlineInputBorder(),
              hintText: "Egzanp: TXN_1776242993483",
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loading ? null : _applyNow,
            child: Text(_loading ? "Ap trete..." : "Apply Commission Now"),
          ),
          const SizedBox(height: 12),
          if (_status.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            "Recent Transactions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _recentTxList(),
        ],
      ),
    );
  }
}
