import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/features/payments/domain/payment_models.dart';
import 'package:mon_premye_app/features/payments/presentation/widgets/payment_error_view.dart';

/// Chak erè Bazik dwe bay yon mesaj ki di SA POU FÈ, pa sèlman sa ki pase.
void main() {
  Future<void> pumpError(WidgetTester tester, PaymentException error) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PaymentErrorView(error: error)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sòld ajan an pa ase: nou di li kisa pou l fè', (tester) async {
    await pumpError(
      tester,
      const PaymentException('insufficient_funds', 'balance too low'),
    );

    expect(find.text('Sòld ou pa ase'), findsOneWidget);
    expect(find.textContaining('Mande yon rechaj'), findsOneWidget);
  });

  testWidgets('float Bazik vid: nou di se administratè a ki dwe aji',
      (tester) async {
    await pumpError(
      tester,
      const PaymentException(
        'gateway_underfunded',
        'Kont Bazik la pa gen ase pwovizyon: 0 HTG disponib.',
      ),
    );

    expect(find.text('Kont Bazik la san pwovizyon'), findsOneWidget);
    expect(find.textContaining('administratè'), findsOneWidget);
  });

  testWidgets('insufficient_balance Bazik la di wallet la ranbouse',
      (tester) async {
    await pumpError(
      tester,
      const PaymentException('insufficient_balance', 'balance insufficient'),
    );

    expect(find.text('Bazik refize: pwovizyon an pa ase'), findsOneWidget);
    expect(find.textContaining('ranbouse'), findsOneWidget);
  });

  testWidgets('minimòm NatCash: mesaj Bazik la pase tèl kèl', (tester) async {
    await pumpError(
      tester,
      const PaymentException(
        'amount_too_low',
        'Minimòm pou natcash se 3998 HTG. Ou mande 1320 HTG.',
      ),
    );

    expect(find.text('Montan an twò piti'), findsOneWidget);
    expect(find.textContaining('3998 HTG'), findsOneWidget);
  });

  testWidgets('kòd la toujou vizib pou ajan an ka site l', (tester) async {
    await pumpError(
      tester,
      const PaymentException('quelque_chose_de_nouveau', 'erreur inconnue'),
    );

    // Menm yon kòd nou pa konnen dwe bay yon mesaj itil.
    expect(find.text('Transfè a pa pase'), findsOneWidget);
    expect(find.textContaining('kòd: quelque_chose_de_nouveau'), findsWidgets);
  });

  testWidgets('erè rezo bay yon bouton "Eseye ankò"', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentErrorView(
            error: const PaymentException('network_error', 'timeout'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eseye ankò'));
    expect(retried, isTrue);
  });

  testWidgets('erè blokan PA bay bouton "Eseye ankò"', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaymentErrorView(
            error: const PaymentException('gateway_underfunded', 'vid'),
            onRetry: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Re-eseye p ap chanje anyen toutotan administratè a pa chaje kont lan.
    expect(find.text('Eseye ankò'), findsNothing);
  });

  test('gravite a klase erè yo kòrèkteman', () {
    PaymentErrorSeverity severityOf(String code) =>
        PaymentErrorInfo.from(PaymentException(code, '')).severity;

    expect(severityOf('amount_too_low'), PaymentErrorSeverity.userFixable);
    expect(severityOf('missing_receiver_name'), PaymentErrorSeverity.userFixable);
    expect(severityOf('network_error'), PaymentErrorSeverity.retryable);
    expect(severityOf('rate_limited'), PaymentErrorSeverity.retryable);
    expect(severityOf('gateway_underfunded'), PaymentErrorSeverity.blocking);
    expect(severityOf('unauthorized'), PaymentErrorSeverity.blocking);
    expect(severityOf('cash_in_unavailable'), PaymentErrorSeverity.blocking);
  });
}
