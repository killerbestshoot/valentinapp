import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/network_minimum_notice.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required String currency,
    Future<Map<String, double>> Function()? loadRates,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NetworkMinimumNotice(
          network: PaymentNetwork.natcash,
          currency: currency,
          loadRates: loadRates ?? () async => {'HTG': 1, 'USD': 132, 'MXN': 7.25},
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  test('minimòm konvèti a awondi AN WO: montan an pase limit la vre', () {
    // 3998 / 132 = 30,2878 -> 30,29 (pa 30,28, ki bay 3996,96 HTG).
    expect(NetworkMinimumNotice.minimumIn(PaymentNetwork.natcash, 132), 30.29);
    expect(30.29 * 132, greaterThanOrEqualTo(3998));
    expect(30.28 * 132, lessThan(3998));

    // 3998 / 7,25 = 551,448 -> 551,45
    expect(NetworkMinimumNotice.minimumIn(PaymentNetwork.natcash, 7.25), 551.45);
  });

  testWidgets('NatCash an USD: ajan an wè minimòm nan nan deviz li', (tester) async {
    await pump(tester, currency: 'USD');

    expect(find.text('NatCash: minimòm 3 998 HTG (30.29 USD)'), findsOneWidget);
    expect(find.textContaining('chwazi MonCash (minimòm 100 HTG)'), findsOneWidget);
  });

  testWidgets('an HTG: pa gen konvèsyon initil', (tester) async {
    await pump(tester, currency: 'HTG');
    expect(find.text('NatCash: minimòm 3 998 HTG'), findsOneWidget);
  });

  testWidgets('to yo pa chaje: avètisman an rete la, an HTG', (tester) async {
    await pump(tester, currency: 'USD', loadRates: () async => throw Exception('offline'));
    expect(find.text('NatCash: minimòm 3 998 HTG'), findsOneWidget);
  });
}
