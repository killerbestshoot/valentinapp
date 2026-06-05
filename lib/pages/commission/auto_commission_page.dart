import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AutoCommissionPage extends StatefulWidget {
  const AutoCommissionPage({super.key});

  @override
  State<AutoCommissionPage> createState() => _AutoCommissionPageState();
}

class _AutoCommissionPageState extends State<AutoCommissionPage> {
  final _urlCtrl = TextEditingController();
  final _limitCtrl = TextEditingController(text: '200');

  bool _loading = false;
  bool _loadingSettings = true;
  String _result = '';

  DocumentReference<Map<String, dynamic>> get _settingsRef =>
      FirebaseFirestore.instance.collection('app_settings').doc('system');

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _limitCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSavedUrl() async {
    try {
      final snap = await _settingsRef.get();
      final data = snap.data() ?? <String, dynamic>{};
      _urlCtrl.text = (data['autoCommissionUrl'] ?? '').toString();
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _loadingSettings = false);
      }
    }
  }

  Future<void> _runNow() async {
    final baseUrl = _urlCtrl.text.trim();
    final limit =
        _limitCtrl.text.trim().isEmpty ? '200' : _limitCtrl.text.trim();

    if (baseUrl.isEmpty) {
      setState(() {
        _result = 'URL la vid. Ale nan Settings pou sove li.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _result = '';
    });

    try {
      final separator = baseUrl.contains('?') ? '&' : '?';
      final url = Uri.parse('$baseUrl${separator}limit=$limit');

      final res = await http.get(url);
      final body = res.body.trim();

      dynamic parsed;
      try {
        parsed = jsonDecode(body);
      } catch (_) {
        parsed = body;
      }

      final pretty = parsed is String
          ? parsed
          : const JsonEncoder.withIndent('  ').convert(parsed);

      setState(() {
        _result = 'HTTP ${res.statusCode}\n\n$pretty';
      });
    } catch (e) {
      setState(() {
        _result = 'Erreur: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  InputDecoration _deco(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Auto Commission Now'),
      ),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _urlCtrl,
                    decoration: _deco(
                      'Cloud Function URL',
                      hint: 'https://...runAutoCommissionNow',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _limitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _deco('Limit'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _runNow,
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        _loading ? 'Running...' : 'Run Auto Commission Now',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _result.isEmpty ? 'Rezilta ap part isit la.' : _result,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
