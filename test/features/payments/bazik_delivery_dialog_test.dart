import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/features/payments/data/fake_payment_gateway.dart';
import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/bazik_delivery_dialog.dart';

void main() {
  group('ki sèvis ki pase sou Bazik', () {
    test('MonCash ak NatCash pase sou pasrèl la', () {
      expect(PaymentNetworkX.forServiceName('MonCash'), PaymentNetwork.moncash);
      expect(PaymentNetworkX.forServiceName('NatCash'), PaymentNetwork.natcash);
      expect(PaymentNetworkX.forServiceName('moncash ht'), PaymentNetwork.moncash);
    });

    test('lòt sèvis yo livre yon lòt jan', () {
      // Sa yo livre fizikman: yo dwe rete `pending` jiskaske yon moun konfime.
      expect(PaymentNetworkX.forServiceName('Western Union'), isNull);
      expect(PaymentNetworkX.forServiceName('CAM Transf'), isNull);
      expect(PaymentNetworkX.forServiceName('Minit Haiti'), isNull);
      expect(PaymentNetworkX.forServiceName(''), isNull);
    });
  });

  Future<void> pumpDialog(
    WidgetTester tester,
    FakePaymentGateway gateway, {
    double amount = 10,
    String serviceName = 'MonCash',
    String phone = '37123456',
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BazikDeliveryDialog(
            txId: 'TX_TEST',
            amount: amount,
            currency: 'USD',
            phone: phone,
            serviceName: serviceName,
            clientName: 'Jean Bastien',
            gateway: gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dyalòg la montre frè yo anvan nou voye', (tester) async {
    await pumpDialog(tester, FakePaymentGateway(balance: 500));

    // 10 USD = 1320 HTG, frè 5% = 66 HTG, debi = 10,50 USD
    expect(find.text('1320.00 HTG'), findsOneWidget);
    expect(find.text('66.00 HTG'), findsOneWidget);
    expect(find.text('10.50 USD'), findsOneWidget);
  });

  testWidgets('transfè ki pase montre ID Bazik la', (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpDialog(tester, gateway);

    await tester.tap(find.text('Voye lajan an'));
    await tester.pumpAndSettle();

    expect(find.text('Transfè a pati.'), findsOneWidget);
    expect(gateway.sent, hasLength(1));
  });

  testWidgets('sòld ki pa ase: erè a parèt ak sa pou fè', (tester) async {
    // 10 USD + frè = 10,50 USD, men wallet la gen 5 USD.
    await pumpDialog(tester, FakePaymentGateway(balance: 5));

    await tester.tap(find.text('Voye lajan an'));
    await tester.pumpAndSettle();

    expect(find.text('Sòld ou pa ase'), findsOneWidget);
    expect(find.textContaining('Mande yon rechaj'), findsOneWidget);
    expect(find.textContaining('kòd: insufficient_funds'), findsOneWidget);
  });

  testWidgets('montan anba minimòm nan: Bazik pa janm rele', (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    // 0,5 USD = 66 HTG, anba 100 HTG minimòm MonCash la.
    await pumpDialog(tester, gateway, amount: 0.5);

    await tester.tap(find.text('Voye lajan an'));
    await tester.pumpAndSettle();

    expect(find.text('Montan an twò piti'), findsOneWidget);
    expect(gateway.sent, isEmpty);
  });

  testWidgets('transfè ki echwe di wallet la ranbouse', (tester) async {
    final gateway = FakePaymentGateway(balance: 500);
    await pumpDialog(tester, gateway, phone: '37000000');

    await tester.tap(find.text('Voye lajan an'));
    await tester.pumpAndSettle();

    expect(find.text('Transfè a pa pase.'), findsOneWidget);
    expect(find.text('Wallet la ranbouse otomatikman.'), findsOneWidget);
    expect(gateway.balance, closeTo(500, 0.001));
  });
}
