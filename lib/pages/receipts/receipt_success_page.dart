import 'package:flutter/material.dart';
import 'package:mon_premye_app/pages/receipts/receipt_pdf_page.dart';

class ReceiptSuccessPage extends StatelessWidget {
  final Map<String, dynamic> tx;

  const ReceiptSuccessPage({
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

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text('Receipt'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111827), Color(0xFF1F2937)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0x22FFFFFF),
                  child: Icon(Icons.check, color: Colors.white, size: 30),
                ),
                SizedBox(height: 12),
                Text(
                  'Tranzaksyon reyisi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Receipt / konfimasyon tranzaksyon an',
                  style: TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        enterpriseName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$amount $currency',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _line('Tx ID', txId),
                _line('Svis', serviceName),
                if (!isMinutes) _line('Non kliyan', customerName),
                _line('Tel kliyan', customerPhone),
                if (isMinutes) ...[
                  _line('Peyi', destinationCountry),
                  _line('Kd', countryCode),
                  _line('Konpayi', telecomCompany),
                ] else ...[
                  _line('Kote kob la prale', receiverLocation),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      side: const BorderSide(color: Color(0xFF111827)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReceiptPdfPage(tx: tx),
                        ),
                      );
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text(
                      'PDF / Print',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF111827),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.home_outlined),
                    label: const Text(
                      'Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
