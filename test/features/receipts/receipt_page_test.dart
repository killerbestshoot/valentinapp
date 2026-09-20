import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/pages/receipts/receipt_page.dart';

class _FakeTransactionApi extends TransactionApi {
  _FakeTransactionApi(this.delivery) : super(client: ApiClient());

  final DeliveryDetails? delivery;

  static const _record = TransactionRecord(
    txId: 'TX_1',
    serviceName: 'MonCash',
    customerName: 'Mari Jozèf',
    customerPhone: '37123456',
    amount: 10,
    currency: 'USD',
    status: 'delivered',
  );

  @override
  Future<({TransactionRecord record, DeliveryDetails? delivery})?>
      findWithDelivery(String txId) async {
    return (record: _record, delivery: delivery);
  }
}

/// 10 USD a 132 = 1 320 HTG, ak 5% frè = 66 HTG.
DeliveryDetails _delivery({required bool feePaidBySender}) {
  return DeliveryDetails(
    amountHtg: 1320,
    rateToHtg: 132,
    rateCurrency: 'USD',
    feeHtg: 66,
    feePercent: 5,
    feePaidBySender: feePaidBySender,
    totalHtg: 1386,
    network: 'moncash',
  );
}

void main() {
  tearDown(TransactionApi.reset);

  Future<void> pumpReceipt(WidgetTester tester, DeliveryDetails? delivery) async {
    TransactionApi.override(_FakeTransactionApi(delivery));

    await tester.pumpWidget(
      const MaterialApp(home: ReceiptPage(transactionId: 'TX_1')),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resi a montre to echanj lan', (tester) async {
    await pumpReceipt(tester, _delivery(feePaidBySender: true));

    expect(find.text('To echanj'), findsOneWidget);
    expect(find.text('1 USD = 132,00 HTG'), findsOneWidget);
  });

  testWidgets('resi a montre sa benefisyè a resevwa an gouden', (tester) async {
    await pumpReceipt(tester, _delivery(feePaidBySender: true));

    expect(find.text('Benefisyè a resevwa'), findsOneWidget);
    expect(find.text('1 320,00 HTG'), findsOneWidget,
        reason: 'chif yo gwoupe: yon ajan pa dwe konte zewo yo');
  });

  testWidgets('resi a di ke ajan an peye frè a anplis', (tester) async {
    await pumpReceipt(tester, _delivery(feePaidBySender: true));

    expect(find.textContaining('66,00 HTG'), findsOneWidget);
    expect(find.textContaining('ajan an peye l anplis'), findsOneWidget);
  });

  testWidgets('resi a di lè frè a retire nan montan an', (tester) async {
    await pumpReceipt(tester, _delivery(feePaidBySender: false));

    expect(find.textContaining('retire nan montan an'), findsOneWidget);
    expect(find.textContaining('ajan an peye l anplis'), findsNothing);
  });

  testWidgets('san transfè, resi a sote liy sa yo', (tester) async {
    await pumpReceipt(tester, null);

    expect(find.text('To echanj'), findsNothing);
    expect(find.text('Benefisyè a resevwa'), findsNothing);
    expect(find.text('Frè'), findsNothing);
    expect(find.text('10.00 USD'), findsWidgets, reason: 'rès resi a la');
  });
}
