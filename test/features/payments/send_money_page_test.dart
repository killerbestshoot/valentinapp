import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/features/payments/data/fake_payment_gateway.dart';
import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/presentation/pages/send_money_page.dart';

/// Tès UI a chita sou `FakePaymentGateway`, ki kopye règ vre pasrèl la
/// (frè 5%, minimòm chak rezo). Konsa nou teste konpòtman an san rezo.
void main() {
  Future<void> tapSend(WidgetTester tester) async {
    await tester.tap(find.text('Voye'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(WidgetTester tester, FakePaymentGateway gateway) async {
    // Ekran tès la se 800x600 pa default: fòm nan + banniere a pa antre ladan,
    // epi tap sou bouton an rate. Nou pran yon ekran ki wo ase.
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: SendMoneyPage(gateway: gateway)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('quote la montre frè yo anvan ajan an voye', (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '10');

    // Quote la gen yon debounce 400ms.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    // 10 USD = 1320 HTG, frè 5% = 66 HTG, debi = 10,50 USD
    expect(find.text('1320.00 HTG'), findsOneWidget);
    expect(find.text('66.00 HTG'), findsOneWidget);
    expect(find.text('10.50 USD'), findsOneWidget);
  });

  testWidgets('NatCash mande non benefisyè a', (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    await tester.tap(find.text('NatCash'));
    await tester.pumpAndSettle();

    expect(find.text('Non konplè benefisyè a'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '50');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nimewo benefisyè a'),
      '37123456',
    );

    await tapSend(tester);

    expect(find.text('Antre non ak siyati.'), findsOneWidget);
    expect(gateway.sent, isEmpty, reason: 'okenn transfè pa dwe pati');
  });

  testWidgets('nimewo ki pa gen 8 chif bloke anvan nou rele pasrèl la',
      (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '10');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nimewo benefisyè a'),
      '3712',
    );

    await tapSend(tester);

    expect(find.text('Nimewo a dwe gen 8 chif.'), findsOneWidget);
    expect(gateway.sent, isEmpty);
  });

  testWidgets('transfè ki reyisi montre referans lan epi sld la bese',
      (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '10');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nimewo benefisyè a'),
      '37123456',
    );

    await tapSend(tester);

    expect(find.text('Transfè a pati'), findsOneWidget);
    expect(gateway.sent, hasLength(1));
    expect(gateway.balance, closeTo(489.5, 0.001));
  });

  testWidgets('transfè ki echwe di ajan an wallet li ranbouse', (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '10');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nimewo benefisyè a'),
      '37000000', // nimewo ki toujou echwe
    );

    await tapSend(tester);

    expect(find.text('Transfè a pa pase'), findsOneWidget);
    expect(find.text('Wallet ou ranbouse otomatikman.'), findsOneWidget);
    expect(gateway.balance, closeTo(500, 0.001), reason: 'sld la pa bouje');
  });

  testWidgets('montan anba minimòm rezo a refize', (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    // 0,5 USD = 66 HTG, anba 100 HTG minimòm MonCash la.
    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '0.5');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nimewo benefisyè a'),
      '37123456',
    );

    await tapSend(tester);

    expect(find.textContaining('Minimòm pou MonCash'), findsOneWidget);
    expect(gateway.sent, isEmpty);
  });

  testWidgets('banniere a avèti lè transfè a p ap rive sou Bazik',
      (tester) async {
    // Se repons lan a kesyon an "poukisa mwen pa wè anyen sou dashboard la".
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    expect(find.text('Mòd similasyon'), findsOneWidget);
    expect(
      find.textContaining('p ap parèt sou dashboard Bazik'),
      findsOneWidget,
    );
  });

  testWidgets('rezilta a montre ID Bazik la (oswa di li pa genyen)',
      (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpPage(tester, gateway);

    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '10');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nimewo benefisyè a'),
      '37123456',
    );
    await tapSend(tester);

    // Similatè a pa bay ID Bazik: UI a dwe di sa klèman.
    expect(
      find.textContaining('ID Bazik: — (transfè a pa rive sou Bazik)'),
      findsOneWidget,
    );
  });

  test('modèl domèn nan konnen règ chak rezo', () {
    expect(PaymentNetwork.moncash.minimumHtg, 100);
    expect(PaymentNetwork.natcash.minimumHtg, 3998);
    expect(PaymentNetwork.natcash.requiresReceiverName, isTrue);
    expect(PaymentNetwork.moncash.requiresReceiverName, isFalse);
  });
}
