import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPdfResult {
  final Uint8List bytes;
  final String fileName;
  final String? savedPath;

  const ReceiptPdfResult({
    required this.bytes,
    required this.fileName,
    this.savedPath,
  });
}

class ReceiptPdfService {
  static double _asDouble(dynamic v) {
    if (v is int) return v.toDouble();
    if (v is double) return v;
    return double.tryParse(v?.toString() ?? '0') ?? 0;
  }

  static String _fmtTs(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      final hh = d.hour.toString().padLeft(2, '0');
      final mi = d.minute.toString().padLeft(2, '0');
      return '${d.year}-$mm-$dd $hh:$mi';
    }
    return '-';
  }

  static Future<ReceiptPdfResult> buildReceiptFromTransactionDocId(
    String transactionDocId,
  ) async {
    final doc = await FirebaseFirestore.instance
        .collection('transactions')
        .doc(transactionDocId)
        .get();

    if (!doc.exists) {
      throw Exception('Transaction pa jwenn.');
    }

    final m = doc.data() ?? <String, dynamic>{};

    final txId = (m['txId'] ?? doc.id).toString();
    final enterpriseName = (m['enterpriseName'] ?? 'VOUPVAPCASH').toString();
    final enterpriseId = (m['enterpriseId'] ?? '').toString();
    final serviceName = (m['serviceName'] ?? '').toString();
    final category = (m['category'] ?? '').toString();
    final customerPhone = (m['customerPhone'] ?? '').toString();
    final beneficiaryName = (m['beneficiaryName'] ?? '').toString();
    final beneficiaryPhone = (m['beneficiaryPhone'] ?? '').toString();
    final staffName = (m['staffName'] ?? '').toString();
    final staffRole = (m['staffRole'] ?? '').toString();
    final paymentStatus = (m['paymentStatus'] ?? '').toString();
    final status = (m['status'] ?? '').toString();
    final note = (m['note'] ?? '').toString();
    final amount = _asDouble(m['paymentAmount']);
    final createdAt = _fmtTs(m['createdAt']);

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Center(
                  child: pw.Text(
                    enterpriseName,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Center(
                  child: pw.Text(
                    'Receipt / Resi',
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 8),
                _line('Transaction ID', txId),
                _line('Enterprise', enterpriseId),
                _line('Service', serviceName),
                _line('Category', category),
                _line('Customer Phone', customerPhone),
                _line('Beneficiary Name', beneficiaryName),
                _line('Beneficiary Phone', beneficiaryPhone),
                _line('Agent', staffName),
                _line('Role', staffRole),
                _line('Amount', '${amount.toStringAsFixed(2)} USD'),
                _line('Payment Status', paymentStatus),
                _line('Status', status),
                _line('Date', createdAt),
                _line('Note', note.isEmpty ? '-' : note),
                pw.SizedBox(height: 12),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Center(
                  child: pw.Text(
                    'Mesi paske ou itilize VOUPVAPCASH',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'Dokiman sa a svi km prv svis la.',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'receipt_$txId.pdf';

    String? savedPath;
    if (!kIsWeb) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      savedPath = file.path;
    }

    return ReceiptPdfResult(
      bytes: bytes,
      fileName: fileName,
      savedPath: savedPath,
    );
  }

  static pw.Widget _line(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 7),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            flex: 6,
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> printReceipt(String transactionDocId) async {
    final result = await buildReceiptFromTransactionDocId(transactionDocId);
    await Printing.layoutPdf(
      onLayout: (format) async => result.bytes,
      name: result.fileName,
    );
  }

  static Future<void> shareReceipt(String transactionDocId) async {
    final result = await buildReceiptFromTransactionDocId(transactionDocId);
    await Printing.sharePdf(
      bytes: result.bytes,
      filename: result.fileName,
    );
  }
}
