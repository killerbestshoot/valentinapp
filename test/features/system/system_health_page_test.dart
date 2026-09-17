import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/airtime/domain/reloadly_overview.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/pages/system/system_health_page.dart';

/// Repons serveur a, jan `/api/system/health` ak `/api/system/reloadly` bay yo.
Map<String, dynamic> healthJson({required bool owner}) => {
      'healthy': false,
      'checks': {
        'database': {'ok': true, 'file': '/data/app.db'},
        'gateway': {'ok': true, 'mode': 'live', 'available': 1000, 'currency': 'HTG', 'funded': true},
        'data': {'stuckTransfers': 0, 'pendingCommissions': 0},
        'solvency': owner
            ? {
                'ok': false,
                'status': 'uncovered',
                'currency': 'HTG',
                'liabilities': {'total': 660000},
                'coverage': {
                  'total': 232000,
                  'bazik': {'ok': true, 'available': 100000, 'currency': 'HTG'},
                  'reloadly': {'ok': true, 'enabled': true, 'available': 1000, 'currency': 'USD'},
                },
                'gap': 428000,
                'reasons': <String>[],
              }
            : {'restricted': true},
      },
    };

Map<String, dynamic> reloadlyJson({required bool owner}) => {
      'enabled': true,
      'mode': 'live',
      'permissions': [
        {'scope': 'send-topups', 'label': 'Voye rechaj minit', 'granted': true, 'ownerOnly': false},
        {'scope': 'read-operators', 'label': 'Li operatè yo', 'granted': true, 'ownerOnly': false},
        {'scope': 'read-promotions', 'label': 'Li pwomosyon yo', 'granted': true, 'ownerOnly': false},
        {'scope': 'read-topups-history', 'label': 'Li istorik rechaj yo', 'granted': true, 'ownerOnly': true},
        {'scope': 'read-prepaid-balance', 'label': 'Li sòld kont lan', 'granted': true, 'ownerOnly': true},
        {'scope': 'read-prepaid-commissions', 'label': 'Li komisyon (remiz) yo', 'granted': false, 'ownerOnly': true},
      ],
      'sections': {
        'operators': {
          'ok': true,
          'data': [
            {
              'operatorId': 173, 'name': 'Digicel Haiti', 'kind': 'airtime', 'status': 'ACTIVE',
              'denominationType': 'RANGE', 'senderCurrency': 'USD', 'minAmount': 4, 'maxAmount': 100,
              'fxRate': 121.46, 'supportsLocalAmounts': false,
            },
            {
              'operatorId': 1296, 'name': 'Natcom Haiti Special Bundle', 'kind': 'bundle',
              'status': 'ACTIVE', 'senderCurrency': 'USD', 'minAmount': 0, 'maxAmount': 0, 'fxRate': 1,
            },
          ],
        },
        'promotions': {'ok': true, 'data': <Map<String, dynamic>>[]},
        'balance': owner
            ? {'ok': true, 'data': {'balance': 962.24, 'currency': 'USD', 'lowBalanceThreshold': 0}}
            : {'ok': false, 'restricted': true},
        'commissions': owner ? {'ok': false, 'error': 'missing_scope'} : {'ok': false, 'restricted': true},
        'history': owner
            ? {
                'ok': true,
                'data': [
                  {
                    'transactionId': '179877', 'status': 'completed', 'operatorName': 'Digicel Haiti',
                    'requestedAmount': 5.81, 'requestedCurrency': 'USD', 'deliveredAmount': 760.49,
                    'deliveredCurrency': 'HTG', 'discount': 0.12, 'date': '2026-09-17 18:00:00',
                  },
                ],
              }
            : {'ok': false, 'restricted': true},
      },
    };

class _FakeSystemApi extends SystemApi {
  _FakeSystemApi({required this.owner}) : super(client: ApiClient());

  final bool owner;

  @override
  Future<SystemHealth> health() async {
    final json = healthJson(owner: owner);
    return SystemHealth(
      healthy: json['healthy'] == true,
      checks: (json['checks'] as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<ReloadlyOverview> reloadly() async => ReloadlyOverview.fromJson(reloadlyJson(owner: owner));
}

void main() {
  tearDown(SystemApi.reset);

  Future<void> pump(WidgetTester tester, {required bool owner}) async {
    SystemApi.override(_FakeSystemApi(owner: owner));
    await tester.binding.setSurfaceSize(const Size(1000, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: SystemHealthPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('owner: alèt solvabilite ak chif ki manke a', (tester) async {
    await pump(tester, owner: true);

    expect(find.text('Solvabilite'), findsOneWidget);
    expect(find.textContaining('MANKE 428000'), findsOneWidget);
    // Chak pwovizyon apa: HTG Bazik la pa ka peye minit.
    expect(find.textContaining('Bazik: 100000 HTG'), findsOneWidget);
    expect(find.textContaining('Reloadly: 1000 USD'), findsOneWidget);
  });

  testWidgets('owner: pèmisyon yo, sòld la ak dènye rechaj yo', (tester) async {
    await pump(tester, owner: true);

    expect(find.text('Voye rechaj minit'), findsOneWidget);
    expect(find.text('Li sòld kont lan'), findsOneWidget);
    expect(find.text('962.24 USD'), findsOneWidget);
    expect(find.textContaining('5.81 USD → 760.49 HTG'), findsOneWidget);
    expect(find.textContaining('bundle · ACTIVE — nou pa vann li'), findsOneWidget);
    expect(find.text('Pa gen pwomosyon kounye a.'), findsOneWidget);
    expect(find.text('Kle API yo pa gen pèmisyon sa a.'), findsOneWidget);
  });

  testWidgets('admin: pèmisyon yo vizib, chif lajan yo rezève', (tester) async {
    await pump(tester, owner: false);

    expect(find.text('Voye rechaj minit'), findsOneWidget);
    expect(find.text('Digicel Haiti #173'), findsOneWidget);

    expect(find.text('Rezève pou owner.'), findsNWidgets(3), reason: 'sòld, komisyon, istorik');
    expect(find.textContaining('Rezève pou owner: se li menm ki wè chif'), findsOneWidget);
    expect(find.text('962.24 USD'), findsNothing);
    expect(find.textContaining('MANKE'), findsNothing);
  });
}
