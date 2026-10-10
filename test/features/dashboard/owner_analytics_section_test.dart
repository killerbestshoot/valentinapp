import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/analytics/data/analytics_api.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/pages/dashboard/owner_analytics_section.dart';

class _FakeAnalyticsApi extends AnalyticsApi {
  _FakeAnalyticsApi() : super(client: ApiClient());

  final calls = <({int days, String currency, AnalyticsGroupBy groupBy, Set<String>? networks})>[];

  @override
  Future<OwnerAnalytics> owner({
    int days = 30,
    String currency = 'HTG',
    AnalyticsGroupBy groupBy = AnalyticsGroupBy.agent,
    Set<String>? networks,
  }) async {
    calls.add((days: days, currency: currency, groupBy: groupBy, networks: networks == null ? null : {...networks}));
    return OwnerAnalytics.fromJson({
      'days': days,
      'currency': currency,
      'generatedAt': DateTime(2026, 10, 9, 16, 40).millisecondsSinceEpoch,
      'kpis': {
        'current': {'count': 10, 'delivered': 8, 'failed': 1, 'pending': 1, 'volume': 18125, 'fee': 900,
          'agentCommission': 360, 'ownerNet': 140, 'successRate': 0.8889, 'averageTicket': 2265.63},
        'previous': {'count': 8, 'delivered': 8, 'failed': 0, 'pending': 0, 'volume': 15000, 'fee': 700,
          'agentCommission': 280, 'ownerNet': 120, 'successRate': 1, 'averageTicket': 1875},
      },
      'series': List.generate(days, (i) => {
            'date': '2026-10-${(i % 28 + 1).toString().padLeft(2, '0')}',
            'count': i % 3, 'delivered': i % 3, 'failed': 0, 'fee': 10, 'ownerNet': 2,
            'volume': {'moncash': 100.0 * (i % 5), 'natcash': 50.0, 'psl': 0, 'minit': 0, 'manual': 0},
          }),
      'groups': [
        {'key': 'u1', 'label': 'Roseline Pierre', 'count': 6, 'delivered': 6, 'volume': 12000, 'share': 0.66,
          'averageTicket': 2000, 'fee': 600, 'agentCommission': 240, 'ownerNet': 100, 'successRate': 1, 'trend': [1, 2, 3]},
        {'key': 'u2', 'label': 'Frantz Augustin', 'count': 4, 'delivered': 2, 'volume': 6125, 'share': 0.34,
          'averageTicket': 3062, 'fee': 300, 'agentCommission': 120, 'ownerNet': -20, 'successRate': 0.6667, 'trend': [3, 2, 1]},
      ],
      'heatmap': List.generate(7, (d) => List.generate(24, (h) => (d + h) % 4)),
      'networkStats': [
        {'network': 'moncash', 'label': 'MonCash', 'count': 7, 'volume': 14000, 'share': 0.77, 'successRate': 0.98, 'medianSeconds': 24},
      ],
      'alerts': [
        {'level': 'critical', 'code': 'transfers_stuck', 'title': '1 transfè pou verifye', 'detail': '500 HTG san repons.'},
      ],
      'recent': [
        {'txId': 'TX_9', 'staffName': 'Roseline Pierre', 'phone': '+509 37 •• •• 89', 'network': 'moncash',
          'amount': 2500, 'currency': 'MXN', 'status': 'delivered', 'createdAt': DateTime(2026, 10, 9, 16, 31).millisecondsSinceEpoch},
      ],
    });
  }
}

class _FakeSystemApi extends SystemApi {
  _FakeSystemApi() : super(client: ApiClient());

  @override
  Future<SystemHealth> health() async => const SystemHealth(healthy: true, checks: {
        'solvency': {
          'status': 'covered',
          'ratio': 1.44,
          'liabilities': {'total': 2148300},
          'coverage': {'total': 3098500},
        },
      });
}

void main() {
  late _FakeAnalyticsApi api;

  setUp(() {
    api = _FakeAnalyticsApi();
    AnalyticsApi.override(api);
    SystemApi.override(_FakeSystemApi());
  });

  tearDown(() {
    AnalyticsApi.reset();
    SystemApi.reset();
  });

  Future<void> pump(WidgetTester tester, {String? opened}) async {
    await tester.binding.setSurfaceSize(const Size(1300, 3600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OwnerAnalyticsSection(isWide: true, refreshEvery: Duration(hours: 1)),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('KPI, solvabilite, gwoup, rezo, alèt ak dènye tranzaksyon parèt', (tester) async {
    await pump(tester);

    expect(find.text('VOLIM LIVRE'), findsOneWidget);
    expect(find.textContaining('18 k HTG', findRichText: true), findsWidgets);
    expect(find.text('+20,8 %'), findsWidgets, reason: '18125 vs 15000 (ak tikè mwayen an)');
    expect(find.text('Kouvri'), findsOneWidget);
    expect(find.text('Roseline Pierre'), findsWidgets);
    expect(find.text('Frantz Augustin'), findsOneWidget);
    expect(find.text('1 transfè pou verifye'), findsOneWidget);
    expect(find.text('Lè chaje'), findsOneWidget);
    expect(find.textContaining('+509 37 •• •• 89'), findsOneWidget);
  });

  testWidgets('chanje peryòd, deviz, gwoupman ak rezo rele serveur a ankò', (tester) async {
    await pump(tester);

    await tester.tap(find.text('7 j'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MXN').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'PSL'));
    await tester.pumpAndSettle();

    final last = api.calls.last;
    expect(last.days, 7);
    expect(last.currency, 'MXN');
    expect(last.groupBy, AnalyticsGroupBy.network);
    expect(last.networks!.contains('psl'), isFalse);
  });

  test('fòma montan yo', () {
    expect(fmtMoney(14500), '14 500,00');
    expect(fmtMoney(-20), '−20,00');
    expect(fmtCompact(1250000), '1,3 M');
    expect(fmtCompact(18125), '18 k');
  });
}
