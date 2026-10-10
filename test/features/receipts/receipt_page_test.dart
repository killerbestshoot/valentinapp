import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/pages/receipts/receipt_page.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeTransactionApi extends TransactionApi {
  _FakeTransactionApi(this.data) : super(client: ApiClient());

  final ReceiptData data;

  @override
  Future<ReceiptData?> findReceipt(String txId) async => data;
}

/// Jean voye 2000 MXN bay Vanessa.
TransactionRecord _tx({double senderFee = 0, String feeMode = 'sender', String status = 'delivered'}) {
  return TransactionRecord(
    txId: 'TX_1',
    serviceName: 'MonCash',
    customerName: 'Vanessa',
    customerPhone: '+50937123456',
    amount: 2000,
    currency: 'MXN',
    status: status,
    senderFee: senderFee,
    feeMode: feeMode,
    staffName: 'Roseline Pierre',
  );
}

/// 2000 MXN a 7,25 = 14 500 HTG pou Vanessa.
const _delivery = DeliveryDetails(
  amountHtg: 14500,
  rateToHtg: 7.25,
  rateCurrency: 'MXN',
  network: 'moncash',
);

const _receipt = ReceiptInfo(
  reference: 'TX_1',
  signature: 'a91f3c0011223344',
  verifyUrl: 'https://voupvapcash.com/api/receipts/verify?tx=TX_1&s=a91f3c0011223344',
);

void main() {
  tearDown(TransactionApi.reset);

  Future<void> pumpReceipt(
    WidgetTester tester, {
    required TransactionRecord record,
    DeliveryDetails? delivery,
    ReceiptInfo? receipt = _receipt,
  }) async {
    await tester.binding.setSurfaceSize(const Size(480, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    TransactionApi.override(
      _FakeTransactionApi(ReceiptData(record: record, delivery: delivery, receipt: receipt)),
    );
    await tester.pumpWidget(const MaterialApp(home: ReceiptPage(transactionId: 'TX_1')));
    await tester.pumpAndSettle();
  }

  testWidgets('gwo chif la: sa benefisyè a resevwa an gouden, gwoupe', (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    expect(find.text('Vanessa resevwa'), findsOneWidget);
    expect(find.textContaining('14 500,00'), findsOneWidget,
        reason: 'chif yo gwoupe: yon ajan pa dwe konte zewo yo');
    expect(find.text('LIVRE'), findsOneWidget);
  });

  testWidgets('resi a montre to echanj lan ak montan voye a', (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    expect(find.text('To echanj'), findsOneWidget);
    expect(find.text('1 MXN = 7,25 HTG'), findsOneWidget);
    expect(find.text('2 000,00 MXN'), findsWidgets);
  });

  testWidgets('anvwayè a peye frè a: 2100 an tou, 100 frè', (tester) async {
    await pumpReceipt(tester, record: _tx(senderFee: 100), delivery: _delivery);

    expect(find.text('KLIYAN AN PEYE AN TOU'), findsOneWidget);
    expect(find.text('2 100,00 MXN'), findsOneWidget);
    expect(find.text('100,00 MXN — anvwayè a peye l anplis'), findsOneWidget);
  });

  testWidgets('frè dedwi: resi a di l', (tester) async {
    await pumpReceipt(
      tester,
      record: const TransactionRecord(
        txId: 'TX_1', serviceName: 'MonCash', customerName: 'Vanessa',
        customerPhone: '+50937123456', amount: 1900, currency: 'MXN', status: 'delivered',
        senderFee: 100, feeMode: 'deducted',
      ),
    );

    expect(find.text('100,00 MXN — dedwi sou montan an'), findsOneWidget);
    expect(find.text('2 000,00 MXN'), findsOneWidget, reason: 'kliyan an bay 2000 an tou');
  });

  testWidgets('san frè', (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    expect(find.text('Pa gen frè'), findsOneWidget);
    expect(find.text('san frè'), findsOneWidget);
  });

  testWidgets('resi a pa janm montre frè pasrèl la', (tester) async {
    await pumpReceipt(tester, record: _tx(senderFee: 100), delivery: _delivery);

    // 5% sou 14 500 HTG = 725 HTG. Kliyan an pa gen anyen pou wè ladan l.
    expect(find.textContaining('725'), findsNothing);
    expect(find.textContaining('pasrèl'), findsNothing);
  });

  testWidgets('nimewo a maske pa defo, switch la montre l', (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    expect(find.text('+509 37 •• •• 56'), findsOneWidget);
    expect(find.text('+50937123456'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('+50937123456'), findsOneWidget);
  });

  testWidgets('QR kòd la pote lyen verifikasyon an', (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    final qr = tester.widget<QrImageView>(find.byType(QrImageView));
    expect(qr, isNotNull);
    expect(find.text('Eskane pou verifye'), findsOneWidget);
  });

  testWidgets('transfè echwe: badj ranbouse, montan an bare', (tester) async {
    await pumpReceipt(tester, record: _tx(status: 'failed', senderFee: 100), delivery: _delivery);

    expect(find.text('ECHWE · RANBOUSE'), findsOneWidget);
    expect(find.text('RANBOUSE BAY KLIYAN AN'), findsOneWidget);
    expect(find.text('Pa livre bay Vanessa'), findsOneWidget);
  });

  testWidgets('san transfè, resi a sote konvèsyon an men li kenbe frè a', (tester) async {
    await pumpReceipt(tester, record: _tx(senderFee: 100));

    expect(find.text('To echanj'), findsNothing);
    expect(find.text('Frè'), findsOneWidget, reason: 'frè a pa depann de to a');
  });

  test('tèks resi a pou kopye', () {
    final text = receiptText(
      ReceiptData(record: _tx(senderFee: 100), delivery: _delivery, receipt: _receipt),
    );
    expect(text, contains('Vanessa resevwa: 14 500,00 HTG'));
    expect(text, contains('Kliyan an peye an tou: 2 100,00 MXN'));
    expect(text, contains('+509 37 •• •• 56'));
    expect(text, contains('Verifye: https://voupvapcash.com/api/receipts/verify'));
  });
}
