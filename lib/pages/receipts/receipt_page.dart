import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';

const _brand = Color(0xFF123D2B);
const _brandSoft = Color(0xFF1E5A40);
const _ink = Color(0xFF172116);
const _muted = Color(0xFF667365);
const _line = Color(0xFFDDE8D8);
const _paper2 = Color(0xFFF2F7EF);
const _accent = Color(0xFF1F7A3A);

/// Lajè resi a an pwen lojik. Imaj la ekspòte a ~1080 px (WhatsApp).
const receiptWidth = 380.0;
const _exportPixels = 1080.0;

/// Resi yon tranzaksyon, pou ekran an E pou pataje an imaj.
///
/// Sa ki sou ekran an se egzakteman sa ki nan imaj la: menm widget la
/// ([ShareableReceipt]) desinen nan yon [RepaintBoundary] epi ekspòte an PNG.
class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  final _captureKey = GlobalKey();
  late final Future<ReceiptData?> _future = TransactionApi.instance.findReceipt(widget.transactionId);

  /// Imaj la sikile: mitan nimewo a kache pa defo.
  bool _maskPhone = true;
  bool _sharing = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<Uint8List?> _png() async {
    final boundary = _captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: _exportPixels / receiptWidth);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes?.buffer.asUint8List();
  }

  Future<void> _shareImage(ReceiptData data) async {
    setState(() => _sharing = true);
    try {
      final bytes = await _png();
      if (bytes == null) {
        _toast('Nou pa ka kreye imaj la.');
        return;
      }
      final name = 'resi-${data.record.txId}.png';
      final result = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: name)],
        fileNameOverrides: [name],
        text: 'Resi VOUPVAPCASH ${data.record.txId}',
      ));
      if (result.status == ShareResultStatus.unavailable) {
        _toast('Imaj la telechaje: ou ka voye l sou WhatsApp.');
      }
    } catch (err) {
      _toast('Pataj la pa mache: $err');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyText(ReceiptData data) async {
    await Clipboard.setData(ClipboardData(text: receiptText(data, maskPhone: _maskPhone)));
    _toast('Resi a kopye.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: _ink,
        centerTitle: true,
        title: const Text('Resi tranzaksyon', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<ReceiptData?>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            final error = snap.error;
            return _StateMessage(
              icon: Icons.error_outline,
              title: 'Erè',
              message: error is ApiException ? error.message : '$error',
            );
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data;
          if (data == null) {
            return const _StateMessage(
              icon: Icons.receipt_long_outlined,
              title: 'Tranzaksyon pa jwenn',
              message: 'Nou pa jwenn resi sa a.',
            );
          }

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: RepaintBoundary(
                              key: _captureKey,
                              child: ShareableReceipt(data: data, maskPhone: _maskPhone),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          value: _maskPhone,
                          onChanged: (v) => setState(() => _maskPhone = v),
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Kache mitan nimewo a sou resi a'),
                        ),
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          onPressed: _sharing ? null : () => _shareImage(data),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brand,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: _sharing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.ios_share),
                          label: const Text('Pataje imaj la'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyText(data),
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                                icon: const Icon(Icons.copy_outlined),
                                label: const Text('Kopye tèks la'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.maybePop(context),
                                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Retounen'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Resi a li menm (ekran + imaj)
// ---------------------------------------------------------------------------

/// Resi a, desinen ak koulè fiks: imaj la pa depann de tèm telefòn nan.
class ShareableReceipt extends StatelessWidget {
  const ShareableReceipt({super.key, required this.data, this.maskPhone = true});

  final ReceiptData data;
  final bool maskPhone;

  @override
  Widget build(BuildContext context) {
    final tx = data.record;
    final delivery = data.delivery;
    final name = tx.customerName.trim().isEmpty ? 'Benefisyè a' : tx.customerName.trim();
    final status = _ReceiptStatus.of(tx.status);
    final failed = status == _ReceiptStatus.failed;

    final headline = switch (status) {
      _ReceiptStatus.delivered => '$name resevwa',
      _ReceiptStatus.failed => 'Pa livre bay $name',
      _ReceiptStatus.pending => '$name ap resevwa',
    };
    final bigAmount = delivery != null ? delivery.amountHtg : tx.amount;
    final bigCurrency = delivery != null ? 'HTG' : tx.currency;

    return SizedBox(
      width: receiptWidth,
      child: Container(
        color: _brand,
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -70,
              top: -70,
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(color: _brandSoft.withValues(alpha: 0.6), shape: BoxShape.circle),
              ),
            ),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: _brand, borderRadius: BorderRadius.circular(9)),
                              child: const Text('V',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('VOUPVAPCASH',
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: _ink)),
                                  Text('Resi tranzaksyon', style: TextStyle(fontSize: 11.5, color: _muted)),
                                ],
                              ),
                            ),
                            _StatusBadge(status: status),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(headline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 13.5, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: groupedMoney(bigAmount),
                                style: TextStyle(
                                  fontSize: 38,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                  color: failed ? _muted : _ink,
                                  decoration: failed ? TextDecoration.lineThrough : null,
                                  decorationColor: const Color(0xFFB91C1C),
                                  decorationThickness: 2,
                                ),
                              ),
                              TextSpan(
                                text: ' $bigCurrency',
                                style: const TextStyle(fontSize: 16, color: _muted, fontWeight: FontWeight.w600),
                              ),
                            ]),
                          ),
                        ),
                        Text('sou ${tx.serviceName} · ${receiptDate(tx.createdAt)}',
                            style: const TextStyle(color: _muted, fontSize: 11.5)),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                          decoration: BoxDecoration(
                            color: failed ? const Color(0xFFFBE4E4) : _paper2,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(failed ? 'RANBOUSE BAY KLIYAN AN' : 'KLIYAN AN PEYE AN TOU',
                                        style: TextStyle(
                                            fontSize: 10,
                                            letterSpacing: 0.8,
                                            fontWeight: FontWeight.w800,
                                            color: failed ? const Color(0xFFB91C1C) : _muted)),
                                    const SizedBox(height: 2),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text('${groupedMoney(tx.totalPaid)} ${tx.currency}',
                                          style: const TextStyle(
                                              fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                tx.hasSenderFee
                                    ? '${groupedMoney(tx.amount)} + ${groupedMoney(tx.senderFee)} frè'
                                    : 'san frè',
                                style: const TextStyle(fontSize: 11, color: _muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._rows(tx, delivery),
                      ],
                    ),
                  ),
                  const _Perforation(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Row(
                      children: [
                        if (data.receipt != null && data.receipt!.verifyUrl.isNotEmpty)
                          QrImageView(
                            data: data.receipt!.verifyUrl,
                            size: 84,
                            padding: EdgeInsets.zero,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: _brand),
                            dataModuleStyle:
                                const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: _brand),
                          )
                        else
                          Container(
                            width: 84,
                            height: 84,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: _paper2, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.qr_code_2, color: _muted, size: 40),
                          ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Eskane pou verifye',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _ink)),
                              SizedBox(height: 3),
                              Text('Kòd la konfime referans lan ak montan an nan sistèm VOUPVAPCASH.',
                                  style: TextStyle(fontSize: 11, color: _muted, height: 1.35)),
                              SizedBox(height: 6),
                              Text('Mèsi paske ou itilize VOUPVAPCASH.',
                                  style: TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _rows(TransactionRecord tx, DeliveryDetails? delivery) {
    final rows = <(String, String, bool)>[
      ('Referans', tx.txId, true),
      ('Dat', receiptDate(tx.createdAt), false),
      ('Sèvis', tx.serviceName, false),
      ('Benefisyè', tx.customerName.trim().isEmpty ? '—' : tx.customerName.trim(), false),
      ('Telefòn', maskPhone ? maskedPhone(tx.customerPhone) : tx.customerPhone, true),
      if (delivery != null) ('Montan voye', '${groupedMoney(tx.amount)} ${tx.currency}', false),
      if (delivery != null) ('To echanj', rateLine(delivery), true),
      ('Frè', senderFeeLine(tx), false),
      if (tx.staffName.trim().isNotEmpty) ('Ajan', tx.staffName.trim(), false),
    ];
    return [
      for (var i = 0; i < rows.length; i++)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            border: i == 0 ? null : const Border(top: BorderSide(color: _line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 92, child: Text(rows[i].$1, style: const TextStyle(color: _muted, fontSize: 12.5))),
              Expanded(
                child: Text(
                  rows[i].$2,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _ink,
                    fontWeight: FontWeight.w600,
                    fontFeatures: rows[i].$3 ? const [FontFeature.tabularFigures()] : null,
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }
}

enum _ReceiptStatus {
  delivered,
  failed,
  pending;

  static _ReceiptStatus of(String s) => switch (s) {
        'delivered' => delivered,
        'failed' || 'canceled' => failed,
        _ => pending,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final _ReceiptStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, fg, bg) = switch (status) {
      _ReceiptStatus.delivered => ('LIVRE', const Color(0xFF15803D), const Color(0xFFE3F3E7)),
      _ReceiptStatus.failed => ('ECHWE · RANBOUSE', const Color(0xFFB91C1C), const Color(0xFFFBE4E4)),
      _ReceiptStatus.pending => ('AN KOU', const Color(0xFFB45309), const Color(0xFFFBEFD9)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

/// Liy pwentiye ak de ti kòch sou kote yo, tankou yon tikè.
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: CustomPaint(painter: _PerforationPainter(), size: const Size(double.infinity, 28)),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final dash = Paint()
      ..color = _line
      ..strokeWidth = 1.5;
    for (double x = 22; x < size.width - 22; x += 10) {
      canvas.drawLine(Offset(x, y), Offset(x + 5, y), dash);
    }
    final notch = Paint()..color = _brand;
    canvas.drawCircle(Offset(0, y), 10, notch);
    canvas.drawCircle(Offset(size.width, y), 10, notch);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Fòma
// ---------------------------------------------------------------------------

/// `13 200,00`. Yon ajan ki li yon resi a vwa wot pa dwe bezwen konte zewo yo.
String groupedMoney(double value) {
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final digits = parts.first;
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i += 1) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(' ');
    grouped.write(digits[i]);
  }
  return '${value < 0 ? '−' : ''}$grouped,${parts.last}';
}

/// `1 USD = 132,00 HTG`. Sa kliyan an bezwen pou l verifye kalkil la li menm.
String rateLine(DeliveryDetails delivery) =>
    '1 ${delivery.rateCurrency} = ${groupedMoney(delivery.rateToHtg)} HTG';

/// `+509 37 •• •• 89`: imaj la sikile, nimewo konplè a pa dwe ladan l.
String maskedPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) return phone;
  final d = digits.substring(digits.length - 8);
  return '+509 ${d.substring(0, 2)} •• •• ${d.substring(6)}';
}

const _months = [
  'janvye', 'fevriye', 'mas', 'avril', 'me', 'jen',
  'jiyè', 'out', 'septanm', 'oktòb', 'novanm', 'desanm',
];

String receiptDate(DateTime? at) {
  if (at == null) return '—';
  final l = at.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.day} ${_months[l.month - 1]} ${l.year} · ${two(l.hour)}:${two(l.minute)}';
}

/// Frè kliyan an peye — pa frè pasrèl la.
///
/// Frè pasrèl la (Bazik, PSL) se yon depans antrepriz la: li pa gade kliyan
/// an, e montre l sou resi a ta fè l kwè se nan lajan pa l li soti.
String senderFeeLine(TransactionRecord tx) {
  if (!tx.hasSenderFee) return 'Pa gen frè';
  final amount = '${groupedMoney(tx.senderFee)} ${tx.currency}';
  return tx.feeDeducted ? '$amount — dedwi sou montan an' : '$amount — anvwayè a peye l anplis';
}

/// Vèsyon tèks resi a (pou kopye).
String receiptText(ReceiptData data, {bool maskPhone = true}) {
  final tx = data.record;
  final d = data.delivery;
  final name = tx.customerName.trim().isEmpty ? 'Benefisyè a' : tx.customerName.trim();
  final status = switch (_ReceiptStatus.of(tx.status)) {
    _ReceiptStatus.delivered => 'Livre',
    _ReceiptStatus.failed => 'Echwe, ranbouse',
    _ReceiptStatus.pending => 'An kou',
  };
  return [
    'VOUPVAPCASH · Resi ${tx.txId}',
    receiptDate(tx.createdAt),
    '$name — ${maskPhone ? maskedPhone(tx.customerPhone) : tx.customerPhone} (${tx.serviceName})',
    if (d != null) '$name resevwa: ${groupedMoney(d.amountHtg)} HTG',
    'Montan voye: ${groupedMoney(tx.amount)} ${tx.currency}',
    if (d != null) 'To echanj: ${rateLine(d)}',
    'Frè: ${senderFeeLine(tx)}',
    'Kliyan an peye an tou: ${groupedMoney(tx.totalPaid)} ${tx.currency}',
    'Estati: $status',
    if (data.receipt != null) 'Verifye: ${data.receipt!.verifyUrl}',
  ].join('\n');
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: _muted),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
          ],
        ),
      ),
    );
  }
}
