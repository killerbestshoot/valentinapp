import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/pages/transactions/transaction_management_page.dart';

class _ListOnlyTransactionApi extends TransactionApi {
  _ListOnlyTransactionApi(this.records) : super(client: ApiClient());

  final List<TransactionRecord> records;

  @override
  Future<List<TransactionRecord>> list({int limit = 25, String? status}) async => records;
}

TransactionRecord _tx(String id, String service, {String status = 'pending'}) => TransactionRecord(
      txId: id,
      serviceName: service,
      customerName: 'Kliyan $id',
      customerPhone: '37123456',
      amount: 5,
      currency: 'USD',
      status: status,
    );

void main() {
  tearDown(TransactionApi.reset);

  testWidgets('chak tranzaksyon gen bouton livrezon PASRÈL PA LI', (tester) async {
    TransactionApi.override(_ListOnlyTransactionApi([
      _tx('TX_M', 'MonCash'),
      _tx('TX_A', 'Minit Haiti'),
      _tx('TX_W', 'Western Union'),
    ]));

    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: TransactionManagementPage()));
    await tester.pumpAndSettle();

    // Anvan: 3 bouton "Livre via Bazik" — youn ladan t ap voye MonCash pou
    // yon vant minit, yon lòt pou yon Western Union.
    expect(find.text('Livre via Bazik'), findsOneWidget);
    expect(find.text('Voye minit'), findsOneWidget);
    expect(find.text('Make manyèl'), findsNWidgets(3));
  });

  testWidgets('yon tranzaksyon LIVRE: okenn bouton ki ka chanje l', (tester) async {
    TransactionApi.override(_ListOnlyTransactionApi([
      _tx('TX_D', 'MonCash', status: 'delivered'),
    ]));

    await tester.binding.setSurfaceSize(const Size(1000, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: TransactionManagementPage()));
    await tester.pumpAndSettle();

    // Serveur a refize (409); UI a dezaktive bouton yo pou di sa davans.
    for (final label in ['Livre via Bazik', 'Make manyèl', 'Pending', 'Efase']) {
      // `find.byType` konpare tip EGZAK la: `ButtonStyleButton` se abstrè.
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull, reason: label);
    }
  });
}
