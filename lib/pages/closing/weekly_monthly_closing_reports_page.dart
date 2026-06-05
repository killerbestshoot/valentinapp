import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class WeeklyMonthlyClosingReportsPage extends StatefulWidget {
  const WeeklyMonthlyClosingReportsPage({super.key});

  @override
  State<WeeklyMonthlyClosingReportsPage> createState() =>
      _WeeklyMonthlyClosingReportsPageState();
}

class _WeeklyMonthlyClosingReportsPageState
    extends State<WeeklyMonthlyClosingReportsPage> {
  String _range = 'week';
  bool _exportingCsv = false;
  bool _exportingPdf = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

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

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _rangeStart() {
    final now = DateTime.now();

    if (_range == 'week') {
      return now.subtract(const Duration(days: 7));
    }

    if (_range == 'month') {
      return DateTime(now.year, now.month, 1);
    }

    if (_range == '30d') {
      return now.subtract(const Duration(days: 30));
    }

    return DateTime(2000);
  }

  bool _inRange(dynamic value) {
    final d = _parseDate(value);
    return !d.isBefore(_rangeStart());
  }

  String _fmtMoney(num value) => value.toStringAsFixed(2);

  String _fmtDate(dynamic value) {
    final d = _parseDate(value);
    if (d.millisecondsSinceEpoch == 0) return '-';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  String _csvCell(dynamic value) {
    final text = (value ?? '').toString().replaceAll('"', '""');
    return '"$text"';
  }

  Future<Directory> _exportDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(
      '${dir.path}${Platform.pathSeparator}VOUPVAPCASH${Platform.pathSeparator}exports',
    );
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
        _csvCell('Day'),
        _csvCell('Staff'),
        _csvCell('Role'),
        _csvCell('Transactions'),
        _csvCell('Sales'),
        _csvCell('AgentCommission'),
        _csvCell('OwnerCommission'),
        _csvCell('Status'),
        _csvCell('ClosedAt'),
      ].join(','));

      for (final doc in _docs) {
        final d = doc.data();
        buffer.writeln([
          _csvCell(enterpriseName),
          _csvCell(d['dayKey']),
          _csvCell(d['staffName']),
          _csvCell(d['staffRole']),
          _csvCell(d['transactionCount']),
          _csvCell(d['totalAmount']),
          _csvCell(d['totalAgentCommission']),
          _csvCell(d['totalOwnerCommission']),
          _csvCell(d['status']),
          _csvCell(d['closedAt']),
        ].join(','));
      }

      final dir = await _exportDir();
      final file = File(
        '${dir.path}${Platform.pathSeparator}closing_report_${enterpriseId}_${_range}_${_fileStamp()}.csv',
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

    num totalSales = 0;
    num totalAgentCommission = 0;
    num totalOwnerCommission = 0;
    int totalTransactions = 0;

    final Map<String, int> staffClosingCount = {};
    final Map<String, num> staffSales = {};
    final Map<String, int> serviceCount = {};
    final Map<String, num> serviceSales = {};

    for (final doc in _docs) {
      final d = doc.data();

      final sales = (d['totalAmount'] as num?) ?? 0;
      final agentComm = (d['totalAgentCommission'] as num?) ?? 0;
      final ownerComm = (d['totalOwnerCommission'] as num?) ?? 0;
      final txCount = (d['transactionCount'] as num?) ?? 0;
      final staffName = (d['staffName'] ?? 'Unknown Staff').toString();

      totalSales += sales;
      totalAgentCommission += agentComm;
      totalOwnerCommission += ownerComm;
      totalTransactions += txCount.toInt();

      staffClosingCount[staffName] = (staffClosingCount[staffName] ?? 0) + 1;
      staffSales[staffName] = (staffSales[staffName] ?? 0) + sales;

      final rawServiceCount =
          (d['serviceCount'] as Map?)?.cast<String, dynamic>() ?? {};
      final rawServiceAmount =
          (d['serviceAmount'] as Map?)?.cast<String, dynamic>() ?? {};

      rawServiceCount.forEach((key, value) {
        final count = value is num ? value.toInt() : 0;
        serviceCount[key] = (serviceCount[key] ?? 0) + count;
      });

      rawServiceAmount.forEach((key, value) {
        final amount = value is num ? value : 0;
        serviceSales[key] = (serviceSales[key] ?? 0) + amount;
      });
    }

    final topStaff = staffClosingCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topServices = serviceCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bestStaffName = topStaff.isEmpty ? '-' : topStaff.first.key;
    final bestServiceName = topServices.isEmpty ? '-' : topServices.first.key;

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'VOUPVAPCASH CLOSING REPORT',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
              'Enterprise: ${(profile['enterpriseName'] ?? '').toString()}'),
          pw.Text('Role: ${(profile['role'] ?? '').toString()}'),
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
          pw.Text('Closings: ${_docs.length}'),
          pw.Text('Transactions: $totalTransactions'),
          pw.Text('Sales: ${_fmtMoney(totalSales)}'),
          pw.Text('Agent Commission: ${_fmtMoney(totalAgentCommission)}'),
          pw.Text('Owner Commission: ${_fmtMoney(totalOwnerCommission)}'),
          pw.Text('Top Staff: $bestStaffName'),
          pw.Text('Top Service: $bestServiceName'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Recent Closings',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          if (_docs.isEmpty)
            pw.Text('Pa gen closing pou peryd sa a')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Day',
                'Staff',
                'Role',
                'Transactions',
                'Sales',
                'Closed At',
              ],
              data: _docs.take(100).map((doc) {
                final d = doc.data();
                return [
                  (d['dayKey'] ?? '').toString(),
                  (d['staffName'] ?? '').toString(),
                  (d['staffRole'] ?? '').toString(),
                  (d['transactionCount'] ?? '').toString(),
                  (d['totalAmount'] ?? '').toString(),
                  _fmtDate(d['closedAt']),
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
      final enterpriseId = (profile['enterpriseId'] ?? '').toString();
      final dir = await _exportDir();
      final bytes = await _buildPdfBytes(profile);

      final file = File(
        '${dir.path}${Platform.pathSeparator}closing_report_${enterpriseId}_${_range}_${_fileStamp()}.pdf',
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

  Widget _line(String left, String right) {
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _closingStream(
      String enterpriseId) {
    return FirebaseFirestore.instance
        .collection('daily_closings')
        .where('enterpriseId', isEqualTo: enterpriseId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly / Monthly Closing Reports'),
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
          final role = (profile['role'] ?? '').toString();
          final enterpriseId = (profile['enterpriseId'] ?? '').toString();

          final isOwner = role == 'owner';
          final isAdmin = role == 'administrator' || role == 'admin';

          if (!isOwner && !isAdmin) {
            return const Center(
              child: Text('Se owner/admin slman ki ka w paj sa a'),
            );
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _closingStream(enterpriseId),
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'ER CLOSINGS: ${snap.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              _docs = snap.data!.docs.where((d) {
                return _inRange(d.data()['closedAt']);
              }).toList()
                ..sort((a, b) {
                  final da = _parseDate(a.data()['closedAt']);
                  final db = _parseDate(b.data()['closedAt']);
                  return db.compareTo(da);
                });

              num totalSales = 0;
              num totalAgentCommission = 0;
              num totalOwnerCommission = 0;
              int totalTransactions = 0;

              final Map<String, int> staffClosingCount = {};
              final Map<String, num> staffSales = {};
              final Map<String, int> serviceCount = {};
              final Map<String, num> serviceSales = {};

              for (final doc in _docs) {
                final d = doc.data();

                final sales = (d['totalAmount'] as num?) ?? 0;
                final agentComm = (d['totalAgentCommission'] as num?) ?? 0;
                final ownerComm = (d['totalOwnerCommission'] as num?) ?? 0;
                final txCount = (d['transactionCount'] as num?) ?? 0;
                final staffName =
                    (d['staffName'] ?? 'Unknown Staff').toString();

                totalSales += sales;
                totalAgentCommission += agentComm;
                totalOwnerCommission += ownerComm;
                totalTransactions += txCount.toInt();

                staffClosingCount[staffName] =
                    (staffClosingCount[staffName] ?? 0) + 1;
                staffSales[staffName] = (staffSales[staffName] ?? 0) + sales;

                final rawServiceCount =
                    (d['serviceCount'] as Map?)?.cast<String, dynamic>() ?? {};
                final rawServiceAmount =
                    (d['serviceAmount'] as Map?)?.cast<String, dynamic>() ?? {};

                rawServiceCount.forEach((key, value) {
                  final count = value is num ? value.toInt() : 0;
                  serviceCount[key] = (serviceCount[key] ?? 0) + count;
                });

                rawServiceAmount.forEach((key, value) {
                  final amount = value is num ? value : 0;
                  serviceSales[key] = (serviceSales[key] ?? 0) + amount;
                });
              }

              final topStaff = staffClosingCount.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final topServices = serviceCount.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));

              final bestStaffName = topStaff.isEmpty ? '-' : topStaff.first.key;
              final bestServiceName =
                  topServices.isEmpty ? '-' : topServices.first.key;

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
                                onPressed: _exportingCsv
                                    ? null
                                    : () => _exportCSV(profile),
                                icon: const Icon(Icons.table_view),
                                label: Text(
                                    _exportingCsv ? 'CSV...' : 'EXPORT CSV'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _exportingPdf
                                    ? null
                                    : () => _exportPDF(profile),
                                icon: const Icon(Icons.picture_as_pdf),
                                label: Text(
                                    _exportingPdf ? 'PDF...' : 'EXPORT PDF'),
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
                        _chip('week', '7 Days'),
                        _chip('month', 'This Month'),
                        _chip('30d', '30 Days'),
                        _chip('all', 'All'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard(
                        'Closings',
                        '${_docs.length}',
                        Icons.event_available,
                        Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Transactions',
                        '$totalTransactions',
                        Icons.receipt_long,
                        Colors.indigo,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard(
                        'Sales',
                        _fmtMoney(totalSales),
                        Icons.attach_money,
                        Colors.green,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Agent Comm.',
                        _fmtMoney(totalAgentCommission),
                        Icons.person,
                        Colors.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _statCard(
                        'Owner Comm.',
                        _fmtMoney(totalOwnerCommission),
                        Icons.admin_panel_settings,
                        Colors.deepPurple,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        'Top Staff',
                        bestStaffName,
                        Icons.emoji_events,
                        Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('Quick Summary'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          _line('Top Staff', bestStaffName),
                          _line('Top Service', bestServiceName),
                          _line('Total Closings', '${_docs.length}'),
                          _line('Total Transactions', '$totalTransactions'),
                          _line('Total Sales', _fmtMoney(totalSales)),
                          _line('Agent Commission',
                              _fmtMoney(totalAgentCommission)),
                          _line('Owner Commission',
                              _fmtMoney(totalOwnerCommission)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionTitle('Top Staff'),
                  if (topStaff.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Pa gen closing pou peryd sa a'),
                      ),
                    )
                  else
                    ...topStaff.take(10).map((e) {
                      final sales = staffSales[e.key] ?? 0;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              _line('Staff', e.key),
                              _line('Closings', '${e.value}'),
                              _line('Sales', _fmtMoney(sales)),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  _sectionTitle('Top Services'),
                  if (topServices.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Pa gen done service pou peryd sa a'),
                      ),
                    )
                  else
                    ...topServices.take(10).map((e) {
                      final sales = serviceSales[e.key] ?? 0;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              _line('Service', e.key),
                              _line('Transactions', '${e.value}'),
                              _line('Sales', _fmtMoney(sales)),
                            ],
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  _sectionTitle('Recent Closings'),
                  if (_docs.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Pa gen recent closing pou peryd sa a'),
                      ),
                    )
                  else
                    ..._docs.take(20).map((doc) {
                      final d = doc.data();
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Day: ${(d['dayKey'] ?? '').toString()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _line('Staff', (d['staffName'] ?? '').toString()),
                              _line('Role', (d['staffRole'] ?? '').toString()),
                              _line(
                                'Transactions',
                                (d['transactionCount'] ?? 0).toString(),
                              ),
                              _line(
                                'Sales',
                                _fmtMoney((d['totalAmount'] as num?) ?? 0),
                              ),
                              _line('Closed At', _fmtDate(d['closedAt'])),
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
      ),
    );
  }
}
