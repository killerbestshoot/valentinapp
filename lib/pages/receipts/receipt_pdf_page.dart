import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReceiptPdfPage extends StatelessWidget {
  final Map<String, dynamic> tx;

  const ReceiptPdfPage({
    super.key,
    required this.tx,
  });

  String _text(dynamic v, [String fallback = '-']) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _money(dynamic v) {
    if (v is int) return v.toDouble().toStringAsFixed(2);
    if (v is double) return v.toStringAsFixed(2);
    if (v is num) return v.toDouble().toStringAsFixed(2);
    return double.tryParse(v?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00';
  }

  pw.Widget _pdfLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Future<pw.Document> _buildPdf() async {
    final pdf = pw.Document();

    final serviceName = _text(tx['serviceName']);
    final customerName = _text(tx['customerName']);
    final customerPhone = _text(tx['customerPhone']);
    final destinationCountry = _text(tx['destinationCountry']);
    final countryCode = _text(tx['countryCode']);
    final telecomCompany = _text(tx['telecomCompany']);
    final receiverLocation = _text(tx['receiverLocation']);
    final amount = _money(tx['paymentAmount']);
    final currency = _text(tx['paymentCurrency'], 'USD');
    final txId = _text(tx['txId']);
    final enterpriseName = _text(tx['enterpriseName'], 'VOUPVAPCASH');

    final isMinutes = telecomCompany != '-' || countryCode != '-';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey900,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      enterpriseName,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'RECEIPT',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text(
                      '$amount $currency',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              _pdfLine('Tx ID', txId),
              _pdfLine('Sevis', serviceName),
              if (!isMinutes) _pdfLine('Non kliyan', customerName),
              _pdfLine('Tel kliyan', customerPhone),
              if (isMinutes) ...[
                _pdfLine('Peyi', destinationCountry),
                _pdfLine('Kd', countryCode),
                _pdfLine('Konpayi', telecomCompany),
              ] else ...[
                _pdfLine('Kote kob la prale', receiverLocation),
              ],
              pw.Spacer(),
              pw.Divider(),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'VOUPVAPCASH - Receipt generated automatically',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt PDF'),
      ),
      body: PdfPreview(
        build: (format) async => (await _buildPdf()).save(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        allowPrinting: true,
        allowSharing: true,
      ),
    );
  }
}
