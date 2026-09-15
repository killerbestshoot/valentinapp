import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/features/users/data/users_api.dart';
import 'package:mon_premye_app/features/wallet/data/wallet_api.dart';
import 'package:mon_premye_app/pages/agent/agents_page.dart';

/// API simile: nou anrejistre apèl yo pou nou wè sa ekran an reyèlman fè.
class _FakeUsersApi extends UsersApi {
  _FakeUsersApi(this._staff);

  List<StaffMember> _staff;
  final List<String> calls = [];

  @override
  Future<List<StaffMember>> list({String? role}) async {
    calls.add('list');
    return _staff;
  }

  @override
  Future<StaffMember> setActive(String uid, bool isActive) async {
    calls.add('setActive:$uid:$isActive');

    _staff = _staff
        .map((member) => member.uid == uid
            ? StaffMember(
                uid: member.uid,
                email: member.email,
                displayName: member.displayName,
                role: member.role,
                isActive: isActive,
                balance: member.balance,
                currency: member.currency,
              )
            : member)
        .toList();

    return _staff.firstWhere((member) => member.uid == uid);
  }
}

/// Wallet simile: nou verifye sa ekran an mande reyèlman.
class _FakeWalletApi extends WalletApi {
  final List<String> calls = [];

  @override
  Future<Map<String, double>> rates() async {
    // Menm valè ak seed la: 1 USD = 132 HTG, 1 MXN = 7.25 HTG.
    return {'HTG': 1, 'MXN': 7.25, 'USD': 132};
  }

  @override
  Future<String> requestTopup({
    required String targetUid,
    required double amount,
    String currency = 'USD',
    String note = '',
    bool autoApprove = false,
  }) async {
    calls.add('topup:$targetUid:$amount:$currency:auto=$autoApprove');
    return 'TU_TEST';
  }
}

StaffMember _agent({bool isActive = true}) => StaffMember(
      uid: 'AG_1',
      email: 'ajan@example.com',
      displayName: 'Ajan Tès',
      role: 'agent',
      isActive: isActive,
      balance: 250,
      currency: 'USD',
    );

void main() {
  tearDown(() {
    UsersApi.reset();
    WalletApi.reset();
  });

  Future<void> pumpPage(WidgetTester tester, _FakeUsersApi api) async {
    UsersApi.override(api);
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: AgentsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('lis la montre ajan an ak sòld li', (tester) async {
    await pumpPage(tester, _FakeUsersApi([_agent()]));

    expect(find.text('Ajan Tès'), findsOneWidget);
    expect(find.text('250.00 USD'), findsOneWidget);
  });

  testWidgets('admin nan ka dezaktive yon ajan', (tester) async {
    final api = _FakeUsersApi([_agent()]);
    await pumpPage(tester, api);

    await tester.tap(find.byTooltip('Dezaktive'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('setActive:AG_1:false'));
    // Apre sa, bouton an dwe pwopoze re-aktive l.
    expect(find.byTooltip('Aktive'), findsOneWidget);
  });

  testWidgets('admin nan ka re-aktive yon ajan dezaktive', (tester) async {
    final api = _FakeUsersApi([_agent(isActive: false)]);
    await pumpPage(tester, api);

    await tester.tap(find.byTooltip('Aktive'));
    await tester.pumpAndSettle();

    expect(api.calls, contains('setActive:AG_1:true'));
  });

  testWidgets('bouton "Nouvo ajan" ouvè ekran kreyasyon an', (tester) async {
    await pumpPage(tester, _FakeUsersApi([_agent()]));

    expect(find.text('Nouvo ajan'), findsOneWidget);

    await tester.tap(find.text('Nouvo ajan'));
    await tester.pumpAndSettle();

    // Ekran kreyasyon an louvri.
    expect(find.text('Nouvo staff'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Imel'), findsOneWidget);
  });

  testWidgets('admin nan ka ajoute fon nan wallet yon ajan', (tester) async {
    final wallet = _FakeWalletApi();
    WalletApi.override(wallet);

    await pumpPage(tester, _FakeUsersApi([_agent()]));

    await tester.tap(find.byTooltip('Ajoute fon'));
    await tester.pumpAndSettle();

    // Sòld aktyèl la parèt pou moun nan konnen kote li soti.
    expect(find.textContaining('250.00 USD'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Montan pou ajoute'),
      '100',
    );
    await tester.tap(find.text('Ajoute'));
    await tester.pumpAndSettle();

    // `auto=true`: owner/admin mete kòb la dirèkteman, san dezyèm etap.
    expect(wallet.calls, contains('topup:AG_1:100.0:USD:auto=true'));
  });

  testWidgets('montan envalid pa voye anyen', (tester) async {
    final wallet = _FakeWalletApi();
    WalletApi.override(wallet);

    await pumpPage(tester, _FakeUsersApi([_agent()]));

    await tester.tap(find.byTooltip('Ajoute fon'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Montan pou ajoute'),
      '0',
    );
    await tester.tap(find.text('Ajoute'));
    await tester.pumpAndSettle();

    expect(find.textContaining('pi gran pase 0'), findsOneWidget);
    expect(wallet.calls, isEmpty);
  });

  testWidgets('deviz la selektab, ak konvèsyon an vizib', (tester) async {
    final wallet = _FakeWalletApi();
    WalletApi.override(wallet);

    await pumpPage(tester, _FakeUsersApi([_agent()]));

    await tester.tap(find.byTooltip('Ajoute fon'));
    await tester.pumpAndSettle();

    // Wallet la an USD: pa gen konvèsyon pou kounye a.
    expect(find.textContaining('Wallet la ap resevwa'), findsNothing);

    // Chwazi MXN.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MXN').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Montan pou ajoute'),
      '1000',
    );
    await tester.pumpAndSettle();

    // 1000 MXN * 7.25 / 132 = 54.92 USD — vizib AVAN validasyon.
    expect(find.textContaining('54.92 USD'), findsOneWidget);

    await tester.tap(find.text('Ajoute'));
    await tester.pumpAndSettle();

    // Nou voye montan an tel kel ak deviz la: se serveur a ki konvèti.
    expect(wallet.calls, contains('topup:AG_1:1000.0:MXN:auto=true'));
  });
}
