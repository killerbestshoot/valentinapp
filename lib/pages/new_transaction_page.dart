import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NewTransactionPage extends StatefulWidget {
  const NewTransactionPage({super.key});

  @override
  State<NewTransactionPage> createState() => _NewTransactionPageState();
}

class _NewTransactionPageState extends State<NewTransactionPage> {

  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();

  bool loading = false;

  String service = "MonCash";
  String currency = "MXN";

  Future<void> saveTransaction() async {

    if (_name.text.trim().isEmpty ||
        _phone.text.trim().isEmpty ||
        _amount.text.trim().isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ranpli tout chan yo"),
        ),
      );

      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseFirestore.instance.collection("transactions").add({

        "service": service,
        "customerName": _name.text.trim(),
        "customerPhone": _phone.text.trim(),
        "amount": double.tryParse(_amount.text.trim()) ?? 0,
        "currency": currency,

        "status": "pending",

        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transaction enregistrée ?"),
        ),
      );

      _name.clear();
      _phone.clear();
      _amount.clear();

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
        ),
      );

    }

    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Nouvo transaction"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(

          children: [

            DropdownButtonFormField<String>(
              value: service,
              items: const [

                DropdownMenuItem(
                  value: "MonCash",
                  child: Text("MonCash"),
                ),

                DropdownMenuItem(
                  value: "NatCash",
                  child: Text("NatCash"),
                ),

                DropdownMenuItem(
                  value: "Minit",
                  child: Text("Minit"),
                ),

              ],

              onChanged: (v) {

                setState(() {
                  service = v!;
                });

              },
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: "Non kliyan",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _phone,
              decoration: const InputDecoration(
                labelText: "Telefòn",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Montan",
              ),
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: currency,
              items: const [

                DropdownMenuItem(
                  value: "MXN",
                  child: Text("MXN"),
                ),

                DropdownMenuItem(
                  value: "HTG",
                  child: Text("HTG"),
                ),

                DropdownMenuItem(
                  value: "USD",
                  child: Text("USD"),
                ),

              ],

              onChanged: (v) {

                setState(() {
                  currency = v!;
                });

              },
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(

                onPressed: loading
                    ? null
                    : saveTransaction,

                child: Text(
                  loading
                      ? "Saving..."
                      : "Save",
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
