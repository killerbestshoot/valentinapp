import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/core/realtime/realtime.dart';
import 'package:mon_premye_app/features/analytics/data/analytics_api.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';
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
  final requested = <String>[];

  @override
  Future<Map<String, double>> rates() async => {'HTG': 1, 'USD': 131, 'MXN': 7.16};

  @override
  Future<List<BankAccount>> bankAccounts() async => const [
        BankAccount(id: 'b1', bankName: 'Unibank', accountName: 'VOUPVAPCASH SA', accountNumber: '120-4455'),
      ];

  @override
  Future<String> requestTopup({
    required String targetUid,
    required double amount,
    String currency = 'USD',
    String note = '',
    bool autoApprove = false,
    String? bankReference,
    String? bankAccountId,
  }) async {
    requested.add('$targetUid:$amount:$currency:$bankReference:$bankAccountId');
    return 'TU_1';
  }
}

class _Auth implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(uid: 'agent_1', email: 'a@x.com', role: AppRole.agent, displayName: 'A');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAnalytics analytics;
  late _FakeTx tx;
  late _FakeWallet wallet;
  setUp(() {
    wallet = _FakeWallet();
    analytics = _FakeAnalytics();
    tx = _FakeTx();
    AnalyticsApi.override(analytics);
    TransactionApi.override(tx);
    WalletApi.override(wallet);
  });
  tearDown(() {
    AnalyticsApi.reset();
    TransactionApi.reset();
    WalletApi.reset();
    AuthRepositoryProvider.reset();
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

  testWidgets('rechaj pa virement bancaire: kont antrepriz la + referans obligatwa', (tester) async {
    AuthRepositoryProvider.override(_Auth());
    tester.view.physicalSize = const Size(1300, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AgentHome(onCreate: () {}, onRepeat: (_) {}, onOpenReceipt: (_) {}, onOpenPayout: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mande rechaj'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Virement bancaire'));
    await tester.pumpAndSettle();

    expect(find.text('120-4455'), findsOneWidget, reason: 'ajan an wè kont antrepriz la');
    await tester.enterText(find.widgetWithText(TextFormField, 'Montan'), '1500');
    await tester.tap(find.text('Voye demann lan'));
    await tester.pumpAndSettle();
    expect(find.text('Antre referans virement an.'), findsOneWidget);
    expect(wallet.requested, isEmpty);

    await tester.enterText(find.widgetWithText(TextFormField, 'Referans virement'), 'UNI-7781');
    await tester.tap(find.text('Voye demann lan'));
    await tester.pumpAndSettle();
    expect(wallet.requested, ['agent_1:1500.0:MXN:UNI-7781:b1']);
  });
}
