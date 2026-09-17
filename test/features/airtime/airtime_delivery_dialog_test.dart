import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/features/airtime/data/fake_airtime_gateway.dart';
import 'package:mon_premye_app/features/airtime/presentation/widgets/airtime_delivery_dialog.dart';

void main() {
  Future<bool?> open(
    WidgetTester tester,
    FakeAirtimeGateway gateway, {
    String phone = '37123456',
    double amount = 5,
  }) async {
    gateway.transactions['TX_9'] = FakeAirtimeTransaction(phone: phone, amount: amount);

    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await AirtimeDeliveryDialog.show(
              context,
              txId: 'TX_9',
              amount: amount,
              currency: 'USD',
              phone: phone,
              clientName: 'Marie',
              gateway: gateway,
            );
          },
          child: const Text('ouvri'),
        ),
      ),
    ));

    await tester.tap(find.text('ouvri'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('devi a parèt ANVAN nenpòt voye', (tester) async {
    final gateway = FakeAirtimeGateway();
    await open(tester, gateway);

    expect(find.text('Digicel Haiti'), findsOneWidget);
    expect(find.text('607.30 HTG'), findsOneWidget);
    expect(find.text('MÒD SIMILASYON: okenn minit p ap pati vre.'), findsOneWidget);
    expect(gateway.delivered, isEmpty);
  });

  testWidgets('voye: minit yo pati, dyalòg la retounen `true`', (tester) async {
    final gateway = FakeAirtimeGateway();
    await open(tester, gateway);

    await tester.tap(find.text('Voye minit yo'));
    await tester.pumpAndSettle();

    expect(find.text('Minit yo pati'), findsOneWidget);
    expect(gateway.delivered, contains('TX_9'));

    await tester.tap(find.text('Fèmen'));
    await tester.pumpAndSettle();
  });

  testWidgets('devi refize (anba minimòm): bouton voye a rete dezaktive', (tester) async {
    final gateway = FakeAirtimeGateway();
    await open(tester, gateway, amount: 0.5);

    expect(find.text('Montan an twò piti'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.ancestor(
      of: find.text('Voye minit yo'),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    ));
    expect(button.onPressed, isNull);
  });

  testWidgets('sèvis la poko aktive (pwodiksyon san kle): mesaj blokan klè', (tester) async {
    final gateway = FakeAirtimeGateway(enabled: false);
    await open(tester, gateway);

    expect(find.text('Minit Haiti poko aktive'), findsOneWidget);
  });
}
