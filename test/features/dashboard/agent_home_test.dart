import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/core/realtime/realtime.dart';
import 'package:mon_premye_app/features/analytics/data/analytics_api.dart';
import 'package:mon_premye_app/features/transactions/data/transaction_api.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/pages/dashboard/agent_home.dart';

class _FakeAnalytics extends AnalyticsApi {
  _FakeAnalytics() : super(client: ApiClient());
  int calls = 0;

  @override
  Future<AgentAnalytics> agent({int days = 1}) async {
    calls++;
    return AgentAnalytics.fromJson({
      'days': days,
      'wallet': {'balance': 2380, 'currency': 'MXN', 'balanceHtg': 17031},
      'kpis': {
        'count': 11, 'delivered': 9, 'failed': 1, 'pending': 1, 'volumeHtg': 152300, 'fee': 950,
        'commissionEarned': 380, 'commissionPending': 40, 'successRate': 0.9, 'averageTicketHtg': 16922, 'currency': 'MXN',
      },
      'commissionSeries': List.generate(7, (i) => {'date': '2026-10-0${i + 3}', 'earned': 50.0 * i, 'pending': i == 6 ? 40.0 : 0.0, 'count': i}),
      'inProgress': [
        {'txId': 'TX_1', 'service': 'MonCash', 'clientName': 'Mirlande Jean', 'phone': '+509 37 •• •• 89',
          'amount': 2500, 'currency': 'MXN', 'status': 'pending', 'manualReview': false},
      ],
    });
  }
}

class _FakeTx extends TransactionApi {
  _FakeTx() : super(client: ApiClient());
  final searches = <String?>[];

  @override
  Future<List<TransactionRecord>> list({int limit = 25, String? status, String? search}) async {
    searches.add(search);
    return const [
      TransactionRecord(txId: 'TX_A', serviceName: 'NatCash', customerName: 'Wesner Louis', customerPhone: '+50941887720',
          amount: 800, currency: 'MXN', status: 'delivered'),
    ];
  }
}

class _FakeWallet extends WalletApi {
  _FakeWallet() : super(client: ApiClient());

  @override
  Future<Map<String, double>> rates() async => {'HTG': 1, 'USD': 131, 'MXN': 7.16};
}

void main() {
  late _FakeAnalytics analytics;
  late _FakeTx tx;
  setUp(() {
    analytics = _FakeAnalytics();
    tx = _FakeTx();
    AnalyticsApi.override(analytics);
    TransactionApi.override(tx);
    WalletApi.override(_FakeWallet());
  });
  tearDown(() {
    AnalyticsApi.reset();
    TransactionApi.reset();
    WalletApi.reset();
  });

  testWidgets('akèy ajan: wallet, aktivite, an kou, favori; tan reyèl rechaje l', (tester) async {
    tester.view.physicalSize = const Size(1300, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    TransactionRecord? repeated;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AgentHome(
          onCreate: () {},
          onRepeat: (t) => repeated = t,
          onOpenReceipt: (_) {},
          onOpenPayout: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 380,00', findRichText: true), findsOneWidget);
    expect(find.text('Nouvo tranzaksyon'), findsOneWidget);
    expect(find.text('Mirlande Jean · 2 500,00 MXN'), findsOneWidget, reason: 'an kou');
    expect(find.text('+40,00 an atant'), findsOneWidget);
    expect(find.text('Sòld ou ba. Mande yon rechaj anvan lè chaje yo.'), findsOneWidget);

    await tester.ensureVisible(find.text('NatCash · 800 MXN'));
    await tester.pumpAndSettle();
    // Kolòn agoch la (wallet, favori, aktivite) dwe gen plas li sou gwo ekran.
    final favorites = find.ancestor(of: find.text('NatCash · 800 MXN'), matching: find.byType(ListView)).first;
    expect(tester.getSize(favorites).width, greaterThan(400));
    await tester.tap(find.text('NatCash · 800 MXN'));
    expect(repeated?.txId, 'TX_A', reason: 'Voye ankò');

    final before = analytics.calls;
    Realtime.instance.debugReceive('change', '{"topics":["transactions"]}');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(analytics.calls, before + 1, reason: 'yon chanjman sou serveur a rechaje akèy la');
  });
}
