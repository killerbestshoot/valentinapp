import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/pages/receipts/receipt_page.dart';

class _FakeTransactionApi extends TransactionApi {
  _FakeTransactionApi({required this.record, this.delivery})
      : super(client: ApiClient());

  final TransactionRecord record;
  final DeliveryDetails? delivery;

  @override
  Future<({TransactionRecord record, DeliveryDetails? delivery})?>
      findWithDelivery(String txId) async {
    return (record: record, delivery: delivery);
  }
}

/// Jean voye 2000 MXN bay Vanessa.
TransactionRecord _tx({double senderFee = 0}) {
  return TransactionRecord(
    txId: 'TX_1',
    serviceName: 'MonCash',
    customerName: 'Vanessa',
    customerPhone: '+50937123456',
    amount: 2000,
    currency: 'MXN',
    status: 'delivered',
    senderFee: senderFee,
  );
}

/// 2000 MXN a 7,25 = 14 500 HTG pou Vanessa.
const _delivery = DeliveryDetails(
  amountHtg: 14500,
  rateToHtg: 7.25,
  rateCurrency: 'MXN',
  network: 'moncash',
);

void main() {
  tearDown(TransactionApi.reset);

  Future<void> pumpReceipt(
    WidgetTester tester, {
    required TransactionRecord record,
    DeliveryDetails? delivery,
  }) async {
    TransactionApi.override(
      _FakeTransactionApi(record: record, delivery: delivery),
    );

    await tester.pumpWidget(
      const MaterialApp(home: ReceiptPage(transactionId: 'TX_1')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resi a montre to echanj lan', (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    expect(find.text('To echanj'), findsOneWidget);
    expect(find.text('1 MXN = 7,25 HTG'), findsOneWidget);
  });

  testWidgets('resi a montre sa benefisyè a resevwa an gouden', (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    expect(find.text('Sa sa fè an gouden'), findsOneWidget);
    expect(find.text('14 500,00 HTG'), findsOneWidget,
        reason: 'chif yo gwoupe: yon ajan pa dwe konte zewo yo');
  });

  testWidgets('Jean peye 2100: resi a montre 100 frè, Vanessa resevwa 2000',
      (tester) async {
    await pumpReceipt(
      tester,
      record: _tx(senderFee: 100),
      delivery: _delivery,
    );

    expect(find.text('Vanessa resevwa'), findsOneWidget);
    expect(find.text('2000.00 MXN'), findsOneWidget, reason: 'sa Vanessa touche');
    expect(find.text('100.00 MXN — anvwayè a peye l anplis'), findsOneWidget);
    expect(find.text('2100.00 MXN'), findsOneWidget,
        reason: 'gwo chif la an tèt resi a: sa Jean peye');
  });

  testWidgets('Jean peye 2000 san frè: Vanessa resevwa menm 2000 an',
      (tester) async {
    await pumpReceipt(tester, record: _tx(), delivery: _delivery);

    expect(find.textContaining('Pa gen frè'), findsOneWidget);
    expect(find.text('2000.00 MXN'), findsNWidgets(2),
        reason: 'san frè, sa Jean peye ak sa Vanessa touche se menm chif la');
  });

  testWidgets('resi a pa janm montre frè pasrèl la', (tester) async {
    await pumpReceipt(
      tester,
      record: _tx(senderFee: 100),
      delivery: _delivery,
    );

    // 5% sou 14 500 HTG = 725 HTG. Kliyan an pa gen anyen pou wè ladan l.
    expect(find.textContaining('725'), findsNothing);
    expect(find.textContaining('Frè pasrèl'), findsNothing);
  });

  testWidgets('san transfè, resi a sote konvèsyon an men li kenbe frè a',
      (tester) async {
    await pumpReceipt(tester, record: _tx(senderFee: 100));

    expect(find.text('To echanj'), findsNothing);
    expect(find.text('Sa sa fè an gouden'), findsNothing);
    expect(find.text('Frè'), findsOneWidget, reason: 'frè a pa depann de to a');
  });
}
