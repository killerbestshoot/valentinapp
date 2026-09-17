import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/airtime/data/airtime_gateway_provider.dart';
import 'package:mon_premye_app/features/airtime/data/fake_airtime_gateway.dart';
import 'package:mon_premye_app/features/payments/data/fake_payment_gateway.dart';
import 'package:mon_premye_app/features/payments/data/payment_gateway_provider.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/pages/transactions/create_transaction_page.dart';

/// Tranzaksyon an memwa. Li anrejistre tou tranzaksyon Minit yo nan pasrèl
/// minit la, jan serveur a ta fè l (montan ak nimewo soti nan tranzaksyon an).
class _FakeTransactionApi extends TransactionApi {
  _FakeTransactionApi(this.airtime) : super(client: ApiClient());

  final FakeAirtimeGateway airtime;
  final List<TransactionRecord> created = [];

  @override
  Future<TransactionRecord> create({
    required String serviceName,
    required String customerName,
    required String customerPhone,
    required double amount,
    required String currency,
    String country = '',
    String note = '',
  }) async {
    final record = TransactionRecord(
      txId: 'TX_${created.length + 1}',
      serviceName: serviceName,
      customerName: customerName,
      customerPhone: customerPhone,
      amount: amount,
      currency: currency,
      status: 'pending',
    );
    created.add(record);
    airtime.transactions[record.txId] = FakeAirtimeTransaction(
      phone: customerPhone,
      amount: amount,
      currency: currency,
    );
    return record;
  }
}

class _FakeWalletApi extends WalletApi {
  _FakeWalletApi() : super(client: ApiClient());

  @override
  Future<Map<String, double>> rates() async =>
      {'HTG': 1, 'USD': 132, 'MXN': 7.25, 'DOP': 2.25, 'CLP': 0.14, 'BRL': 24};
}

void main() {
  late FakePaymentGateway payments;
  late FakeAirtimeGateway airtime;
  late _FakeTransactionApi transactions;

  setUp(() {
    payments = FakePaymentGateway(balance: 500);
    airtime = FakeAirtimeGateway();
    transactions = _FakeTransactionApi(airtime);

    PaymentGatewayProvider.override(payments);
    AirtimeGatewayProvider.override(airtime);
    TransactionApi.override(transactions);
    WalletApi.override(_FakeWalletApi());
  });

  tearDown(() {
    PaymentGatewayProvider.reset();
    AirtimeGatewayProvider.reset();
    TransactionApi.reset();
    WalletApi.reset();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: CreateTransactionPage()));
    await tester.pumpAndSettle();
  }

  // Pa `find.text('MonCash')`: kat "Rezime" a montre menm tèks la anlè fòm
  // nan, e yon tap sou li pa louvri meni an.
  Finder dropdown(int index) =>
      find.byType(DropdownButtonFormField<String>).at(index);

  Future<void> chooseService(WidgetTester tester, String service) async {
    await tester.tap(dropdown(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(service).last);
    await tester.pumpAndSettle();
  }

  Future<void> chooseCurrency(WidgetTester tester, String to) async {
    await tester.tap(dropdown(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(to).last);
    await tester.pumpAndSettle();
  }

  Future<void> fill(
    WidgetTester tester, {
    required String name,
    required String phone,
    required String amount,
  }) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Non kliyan'), name);
    await tester.enterText(find.widgetWithText(TextFormField, 'Telefòn'), phone);
    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), amount);
    // Devi an dirèk la gen yon debounce 400 ms.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Anrejistre epi voye'));
    await tester.tap(find.text('Anrejistre epi voye'));
    await tester.pumpAndSettle();
  }

  group('NatCash: minimòm 3 998 HTG', () {
    testWidgets('avètisman an parèt DEPI NatCash chwazi, nan deviz ajan an', (tester) async {
      await pumpPage(tester);

      expect(find.byKey(const ValueKey('network-minimum-notice')), findsNothing);

      await chooseService(tester, 'NatCash');
      await chooseCurrency(tester, 'USD');

      expect(find.text('NatCash: minimòm 3 998 HTG (30.29 USD)'), findsOneWidget);
    });

    testWidgets('montan anba minimòm: erè a parèt PANDAN ajan an ap tape', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'NatCash');
      await chooseCurrency(tester, 'USD');

      // 10 USD = 1 320 HTG < 3 998
      await fill(tester, name: 'Jean Pierre', phone: '37123456', amount: '10');

      expect(find.text('Montan an twò piti'), findsOneWidget);
      expect(transactions.created, isEmpty);
    });

    testWidgets('anrejistre anba minimòm: OKENN tranzaksyon pa kreye', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'NatCash');
      await chooseCurrency(tester, 'USD');
      await fill(tester, name: 'Jean Pierre', phone: '37123456', amount: '10');

      await save(tester);

      expect(find.text('Montan an twò piti'), findsOneWidget);
      expect(
        transactions.created,
        isEmpty,
        reason: 'anvan, tranzaksyon an te kreye epi voye a te echwe apre: yon `pending` òfelen',
      );
      expect(payments.sent, isEmpty);
    });

    testWidgets('anrejistre AN WO minimòm: tranzaksyon an kreye epi voye', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'NatCash');
      await chooseCurrency(tester, 'USD');
      await fill(tester, name: 'Jean Pierre', phone: '37123456', amount: '30.29');

      await save(tester);

      expect(transactions.created, hasLength(1));
      expect(payments.sent, hasLength(1));
      expect(find.text('Lajan an pati'), findsOneWidget);
    });
  });

  group('Minit Haiti (Reloadly)', () {
    testWidgets('kliyan an peye an MXN: konvèsyon an USD vizib, debi nan deviz wallet la', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'Minit Haiti');
      await chooseCurrency(tester, 'MXN');
      await fill(tester, name: 'Marie', phone: '3712 3456', amount: '100');

      // 100 MXN × 7,25 / 132 = 5,4924 USD: 5,49 voye (an ba), 5,49 debite.
      expect(find.text('Kliyan an peye'), findsOneWidget);
      expect(find.text('100.00 MXN'), findsWidgets);
      expect(find.text('Voye bay Reloadly'), findsOneWidget);
      expect(find.text('5.49 USD'), findsWidgets);
      expect(find.textContaining('1 MXN = 0.0549 USD'), findsOneWidget);

      await save(tester);

      expect(transactions.created.single.currency, 'MXN');
      expect(find.text('Minit yo pati'), findsOneWidget);
    });

    testWidgets('MonCash an MXN: debi a parèt nan deviz WALLET la (USD)', (tester) async {
      await pumpPage(tester);
      await chooseCurrency(tester, 'MXN');
      await fill(tester, name: 'Jean', phone: '37123456', amount: '100');

      // 100 MXN = 725 HTG, +5% = 761,25 HTG, / 132 = 5,77 USD
      expect(find.text('725.00 HTG'), findsOneWidget);
      expect(find.text('5.77 USD'), findsOneWidget);
    });

    testWidgets('devi a montre operatè a ak sa benefisyè a resevwa', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'Minit Haiti');
      await chooseCurrency(tester, 'USD');
      await fill(tester, name: 'Marie', phone: '3712 3456', amount: '5');

      expect(find.text('Digicel Haiti'), findsOneWidget);
      expect(find.text('607.30 HTG'), findsOneWidget);
      expect(find.text('5.00 USD'), findsWidgets);
    });

    testWidgets('anrejistre: tranzaksyon an kreye, minit yo livre', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'Minit Haiti');
      await chooseCurrency(tester, 'USD');
      await fill(tester, name: 'Marie', phone: '33123456', amount: '5');

      await save(tester);

      expect(transactions.created, hasLength(1));
      expect(transactions.created.single.serviceName, 'Minit Haiti');
      expect(airtime.delivered, contains('TX_1'));
      expect(find.text('Minit yo pati'), findsOneWidget);
      expect(find.textContaining('Natcom Haiti'), findsWidgets);
    });

    testWidgets('montan anba minimòm operatè a: OKENN tranzaksyon pa kreye', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'Minit Haiti');
      await chooseCurrency(tester, 'USD');
      await fill(tester, name: 'Marie', phone: '37123456', amount: '0.5');

      await save(tester);

      expect(find.text('Montan an twò piti'), findsOneWidget);
      expect(transactions.created, isEmpty);
      expect(airtime.delivered, isEmpty);
    });

    testWidgets('Reloadly refize: ajan an wè ke wallet li ranbouse', (tester) async {
      await pumpPage(tester);
      await chooseService(tester, 'Minit Haiti');
      await chooseCurrency(tester, 'USD');
      await fill(tester, name: 'Marie', phone: '37000000', amount: '5');

      await save(tester);

      expect(find.text('Rechaj la pa pase'), findsOneWidget);
      expect(find.text('Wallet ou ranbouse otomatikman.'), findsOneWidget);
    });
  });
}
