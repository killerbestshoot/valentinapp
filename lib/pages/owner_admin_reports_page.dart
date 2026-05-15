import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class OwnerAdminReportsPage extends StatefulWidget {
  const OwnerAdminReportsPage({super.key});

  @override
  State<OwnerAdminReportsPage> createState() => _OwnerAdminReportsPageState();
}

class _OwnerAdminReportsPageState extends State<OwnerAdminReportsPage> {
  String _range = 'today';
  bool _exportingCsv = false;
  bool _exportingPdf = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _txDocs = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _validationDocs = [];

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  Future<Map<String, dynamic>> _getProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User pa konekte');
    }

    final db = FirebaseFirestore.instance;

    final userDoc = await db.collection('users').doc(user.uid).get();
    final entSnap = await db
        .collection('enterprise_users')
        .where('uid', isEqualTo: user.uid)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (entSnap.docs.isEmpty) {
      throw Exception('Enterprise pa jwenn');
    }

    final ent = entSnap.docs.first.data();

    return {
      'uid': user.uid,
      'displayName': (userDoc.data()?['displayName'] ?? '').toString(),
      'role': (ent['role'] ?? '').toString().toLowerCase().trim(),
      'enterpriseId': (ent['enterpriseId'] ?? '').toString(),
      'enterpriseName': (ent['enterpriseName'] ?? '').toString(),
    };
  }

  DateTime _rangeStart() {
    final now = DateTime.now();

    if (_range == 'today') {
      return DateTime(now.year, now.month, now.day);
    }
    if (_range == '7d') {
      return now.subtract(const Duration(days: 7));
    }
    if (_range == '30d') {
      return now.subtract(const Duration(days: 30));
    }
    return DateTime(2000);
  }

  bool _inRange(dynamic createdAt) {
    final dt = _parseDate(createdAt);
    return !dt.isBefore(_rangeStart());
  }

  String _csvCell(dynamic value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  Future<Directory> _exportDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory('${dir.path}${Platform.pathSeparator}VOUPVAPCASH${Platform.pathSeparator}exports');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  String _fileStamp() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  Future<void> _exportCSV(Map<String, dynamic> profile) async {
    if (_exportingCsv) return;

    setState(() {
      _exportingCsv = true;
    });

    try {
      final enterpriseId = (profile['enterpriseId'] ?? '').toString();
      final enterpriseName = (profile['enterpriseName'] ?? '').toString();

      final buffer = StringBuffer();
      buffer.writeln([
        _csvCell('Enterprise'),
        _csvCell('TxId'),
        _csvCell('Service'),
        _csvCell('Agent'),
        _csvCell('Customer'),
        _csvCell('Phone'),
        _csvCell('Amount'),
        _csvCell('Currency'),
        _csvCell('AgentCommission'),
        _csvCell('OwnerCommission'),
        _csvCell('Status'),
        _csvCell('CreatedAt'),
      ].join(','));

      for (final doc in _txDocs) {
        final d = doc.data();
        buffer.writeln([
          _csvCell(enterpriseName),
          _csvCell(d['txId']),
          _csvCell(d['serviceName']),
          _csvCell(d['staffName']),
          _csvCell(d['customerName']),
          _csvCell(d['customerPhone']),
          _csvCell(d['paymentAmount']),
          _csvCell(d['paymentCurrency']),
          _csvCell(d['commissionAgent']),
          _csvCell(d['commissionOwner']),
          _csvCell(d['status']),
          _csvCell(d['createdAt']),
        ].join(','));
      }

      final dir = await _exportDir();
      final file = File(
        '${dir.path}${Platform.pathSeparator}report_${enterpriseId}_${_range}_${_fileStamp()}.csv',
      );

      await file.writeAsString(buffer.toString(), flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV export fini: ${file.path}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER CSV export: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingCsv = false;
        });
      }
    }
  }

  Future<Uint8List> _buildPdfBytes(Map<String, dynamic> profile) async {
    final pdf = pw.Document();

    final enterpriseName = (profile['enterpriseName'] ?? '').toString();
    final role = (profile['role'] ?? '').toString();

    num totalAmount = 0;
    num totalAgentCommission = 0;
    num totalOwnerCommission = 0;

    for (final doc in _txDocs) {
      final d = doc.data();
      totalAmount += (d['paymentAmount'] as num?) ?? 0;
      totalAgentCommission += (d['commissionAgent'] as num?) ?? 0;
      totalOwnerCommission += (d['commissionOwner'] as num?) ?? 0;
    }

    int validCount = 0;
    int invalidCount = 0;
    int suspiciousCount = 0;

    for (final doc in _validationDocs) {
      final status = (doc.data()['status'] ?? '').toString().toLowerCase().trim();
      if (status == 'valid') validCount++;
      if (status == 'invalid') invalidCount++;
      if (status == 'suspicious') suspiciousCount++;
    }

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'VOUPVAPCASH OWNER / ADMIN REPORT',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Enterprise: $enterpriseName'),
          pw.Text('Role: $role'),
          pw.Text('Range: $_range'),
          pw.Text('Generated At: ${DateTime.now().toIso8601String()}'),
          pw.SizedBox(height: 16),

          pw.Text(
            'Summary',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Transactions: ${_txDocs.length}'),
          pw.Text('Total Amount: ${_fmtMoney(totalAmount)}'),
          pw.Text('Agent Commission: ${_fmtMoney(totalAgentCommission)}'),
          pw.Text('Owner Commission: ${_fmtMoney(totalOwnerCommission)}'),
          pw.Text('Valid Receipts: $validCount'),
          pw.Text('Suspicious Receipts: $suspiciousCount'),
          pw.Text('Invalid Receipts: $invalidCount'),
          pw.SizedBox(height: 16),

          pw.Text(
            'Transactions',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),

          if (_txDocs.isEmpty)
            pw.Text('Pa gen tranzaksyon pou peryd sa a')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'TxId',
                'Service',
                'Agent',
                'Amount',
                'Currency',
                'Status',
              ],
              data: _txDocs.take(100).map((doc) {
                final d = doc.data();
                return [
                  (d['txId'] ?? '').toString(),
                  (d['serviceName'] ?? '').toString(),
                  (d['staffName'] ?? '').toString(),
                  (d['paymentAmount'] ?? '').toString(),
                  (d['paymentCurrency'] ?? '').toString(),
                  (d['status'] ?? '').toString(),
                ];
              }).toList(),
            ),
        ],
      ),
    );

    return pdf.save();
  }

  Future<void> _exportPDF(Map<String, dynamic> profile) async {
    if (_exportingPdf) return;

    setState(() {
      _exportingPdf = true;
    });

    try {
      final bytes = await _buildPdfBytes(profile);

      final enterpriseId = (profile['enterpriseId'] ?? '').toString();
      final dir = await _exportDir();
      final file = File(
        '${dir.path}${Platform.pathSeparator}report_${enterpriseId}_${_range}_${_fileStamp()}.pdf',
      );

      await file.writeAsBytes(bytes, flush: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export fini: ${file.path}')),
      );

      await Printing.layoutPdf(
        onLayout: (format) async => bytes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ER PDF export: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exportingPdf = false;
        });
      }
    }
  }

  Widget _chip(String value, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _range == value,
        onSelected: (_) {
          setState(() {
            _range = value;
          });
        },
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _rowLine(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(right),
        ],
      ),
    );
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _txStream(String enterpriseId) {
    return FirebaseFirestore.instance
        .collection('transactions')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _validationLogsStream() {
    return FirebaseFirestore.instance
        .collection('receipt_validation_logs')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner/Admin Reports'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _getProfile(),
        builder: (context, profileSnap) {
          if (profileSnap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'ER PROFILE: ${profileSnap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!profileSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profile = profileSnap.data!;
          final enterpriseId = (profile['enterpriseId'] ?? '').toString();
          final role = (profile['role'] ?? '').toString();

          final isOwner = role == 'owner';
          final isAdmin = role == 'administrator' || role == 'admin';

          if (!isOwner && !isAdmin) {
            return const Center(
              child: Text('Se owner/admin slman ki ka w reports sa yo'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _txStream(enterpriseId),
            builder: (context, txSnap) {
              if (txSnap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER TRANSACTIONS: ${txSnap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!txSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _validationLogsStream(),
                builder: (context, logsSnap) {
                  if (logsSnap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'ER VALIDATION LOGS: ${logsSnap.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  if (!logsSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  _txDocs = txSnap.data!.docs
                      .where((d) => _inRange(d.data()['createdAt']))
                      .toList();

                  _validationDocs = logsSnap.data!.docs.where((d) {
                    final data = d.data();
                    final sameEnterprise =
                        (data['enterpriseId'] ?? '').toString() == enterpriseId;
                    return sameEnterprise && _inRange(data['createdAt']);
                  }).toList();

                  num totalAmount = 0;
                  num totalAgentCommission = 0;
                  num totalOwnerCommission = 0;

                  final Map<String, int> byAgentCount = {};
                  final Map<String, num> byAgentAmount = {};

                  final Map<String, int> byServiceCount = {};
                  final Map<String, num> byServiceAmount = {};

                  for (final doc in _txDocs) {
                    final d = doc.data();

                    final amount = (d['paymentAmount'] as num?) ?? 0;
                    final agentCommission = (d['commissionAgent'] as num?) ?? 0;
                    final ownerCommission = (d['commissionOwner'] as num?) ?? 0;

                    final agentName = (d['staffName'] ?? 'Unknown Agent')
                            .toString()
                            .trim()
                            .isEmpty
                        ? 'Unknown Agent'
                        : (d['staffName'] ?? 'Unknown Agent').toString();

                    final serviceName = (d['serviceName'] ?? 'Unknown Service')
                            .toString()
                            .trim()
                            .isEmpty
                        ? 'Unknown Service'
                        : (d['serviceName'] ?? 'Unknown Service').toString();

                    totalAmount += amount;
                    totalAgentCommission += agentCommission;
                    totalOwnerCommission += ownerCommission;

                    byAgentCount[agentName] = (byAgentCount[agentName] ?? 0) + 1;
                    byAgentAmount[agentName] = (byAgentAmount[agentName] ?? 0) + amount;

                    byServiceCount[serviceName] = (byServiceCount[serviceName] ?? 0) + 1;
                    byServiceAmount[serviceName] = (byServiceAmount[serviceName] ?? 0) + amount;
                  }

                  int validCount = 0;
                  int invalidCount = 0;
                  int suspiciousCount = 0;

                  for (final doc in _validationDocs) {
                    final status =
                        (doc.data()['status'] ?? '').toString().toLowerCase().trim();
                    if (status == 'valid') validCount++;
                    if (status == 'invalid') invalidCount++;
                    if (status == 'suspicious') suspiciousCount++;
                  }

                  final agentEntries = byAgentCount.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  final serviceEntries = byServiceCount.entries.toList()
                    ..sort((a, b) => b.value.compareTo(a.value));

                  return ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (profile['enterpriseName'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('Role: $role'),
                              Text('EnterpriseId: $enterpriseId'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _exportingCsv ? null : () => _exportCSV(profile),
                                    icon: const Icon(Icons.table_view),
                                    label: Text(_exportingCsv ? 'CSV...' : 'EXPORT CSV'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _exportingPdf ? null : () => _exportPDF(profile),
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: Text(_exportingPdf ? 'PDF...' : 'EXPORT PDF'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _chip('today', 'Today'),
                            _chip('7d', '7 Days'),
                            _chip('30d', '30 Days'),
                            _chip('all', 'All'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _statCard(
                            'Transactions',
                            '${_txDocs.length}',
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                          const SizedBox(width: 10),
                          _statCard(
                            'Total Amount',
                            _fmtMoney(totalAmount),
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _statCard(
                            'Agent Commission',
                            _fmtMoney(totalAgentCommission),
                            Icons.person,
                            Colors.teal,
                          ),
                          const SizedBox(width: 10),
                          _statCard(
                            'Owner Commission',
                            _fmtMoney(totalOwnerCommission),
                            Icons.admin_panel_settings,
                            Colors.deepPurple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _statCard(
                            'Valid Receipts',
                            '$validCount',
                            Icons.verified,
                            Colors.green,
                          ),
                          const SizedBox(width: 10),
                          _statCard(
                            'Suspicious',
                            '$suspiciousCount',
                            Icons.warning,
                            Colors.orange,
                          ),
                          const SizedBox(width: 10),
                          _statCard(
                            'Invalid',
                            '$invalidCount',
                            Icons.cancel,
                            Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _sectionTitle('Top Agents'),
                      if (agentEntries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Pa gen done agent pou peryd sa a'),
                          ),
                        )
                      else
                        ...agentEntries.take(10).map((e) {
                          final amount = byAgentAmount[e.key] ?? 0;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  _rowLine('Agent', e.key),
                                  _rowLine('Transactions', '${e.value}'),
                                  _rowLine('Total Amount', _fmtMoney(amount)),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 14),
                      _sectionTitle('Top Services'),
                      if (serviceEntries.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text('Pa gen done service pou peryd sa a'),
                          ),
                        )
                      else
                        ...serviceEntries.take(10).map((e) {
                          final amount = byServiceAmount[e.key] ?? 0;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  _rowLine('Service', e.key),
                                  _rowLine('Transactions', '${e.value}'),
                                  _rowLine('Total Amount', _fmtMoney(amount)),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}