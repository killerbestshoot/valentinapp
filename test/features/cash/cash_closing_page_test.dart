import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';
import 'package:mon_premye_app/features/cash/data/cash_api.dart';
import 'package:mon_premye_app/pages/cash/cash_closing_page.dart';

class _Auth implements AuthRepository {
  _Auth(this.role);
  final AppRole role;

  @override
  AuthUser? get currentUser => AuthUser(uid: 'me', email: 'x@x.com', role: role, displayName: 'Moi');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCash extends CashApi {
  _FakeCash() : super(client: ApiClient());
  final submitted = <Map<String, dynamic>>[];
  final decisions = <String>[];

  static const _closing = CashClosing(
    closingId: 'CK_1',
    staffUid: 'agent_1',
    staffName: 'Mirlande',
    date: '2026-10-12',
    status: 'submitted',
    note: 'Monnen bay pa erè',
    balanced: false,
    lines: [CashLine(currency: 'MXN', opening: 500, sales: 3300, deposit: 2000, expected: 1800, counted: 1750, variance: -50)],
  );

  @override
  Future<CashExpected> expected({String? date, String? uid}) async => const CashExpected(
        date: '2026-10-12',
        today: '2026-10-12',
        currencies: [CashCurrency(currency: 'MXN', sales: 3300, txCount: 2, pendingCount: 1, suggestedOpening: 500)],
      );

  @override
  Future<CashClosing> submit({required String date, required List<Map<String, dynamic>> lines, String note = ''}) async {
    submitted.add({'date': date, 'lines': lines, 'note': note});
    return _closing;
  }

  @override
  Future<CashClosingList> list({required String from, required String to, String? status}) async =>
      const CashClosingList(closings: [_closing], variance: {'MXN': -50}, pending: 1, missingToday: ['Wesner']);

  @override
  Future<CashClosing> validate(String id, {String note = ''}) async {
    decisions.add('validate:$id');
    return _closing;
  }
}

void main() {
  late _FakeCash cash;
  setUp(() {
    cash = _FakeCash();
    CashApi.override(cash);
  });
  tearDown(() {
    CashApi.reset();
    AuthRepositoryProvider.reset();
  });

  Future<void> pump(WidgetTester tester, AppRole role) async {
    AuthRepositoryProvider.override(_Auth(role));
    await tester.binding.setSurfaceSize(const Size(900, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: CashClosingPage())));
    await tester.pumpAndSettle();
  }

  testWidgets('ajan: kès atann kalkile, ekar parèt, nòt obligatwa', (tester) async {
    await pump(tester, AppRole.agent);

    expect(find.text('Fèmti ajan yo'), findsNothing, reason: 'ajan an wè sèlman kès pa l');
    expect(find.text('+3 300,00 MXN'), findsOneWidget, reason: 'lavant yo soti nan sèvè a');
    expect(find.text('3 800,00 MXN'), findsOneWidget, reason: 'kès atann = 500 + 3300');

    await tester.enterText(find.byKey(const ValueKey('deposit-MXN')), '2000');
    await tester.enterText(find.byKey(const ValueKey('counted-MXN')), '1750');
    await tester.pump();
    expect(find.text('1 800,00 MXN'), findsOneWidget);
    expect(find.text('Manke 50,00 MXN'), findsOneWidget);

    await tester.tap(find.text('Voye fèmti kès la'));
    await tester.pump();
    expect(cash.submitted, isEmpty, reason: 'ekar san nòt');

    await tester.enterText(find.byKey(const ValueKey('cash-note')), 'Monnen bay pa erè');
    await tester.tap(find.text('Voye fèmti kès la'));
    await tester.pumpAndSettle();
    expect(cash.submitted.single['lines'], [
      {'currency': 'MXN', 'opening': 500.0, 'deposit': 2000.0, 'counted': 1750.0},
    ]);
    expect(find.text('Voye. L ap tann validasyon administratè a.'), findsOneWidget);
  });

  testWidgets('owner: rezime, ajan ki poko fèmen, valide', (tester) async {
    await pump(tester, AppRole.owner);

    expect(find.text('Pou valide'), findsOneWidget);
    expect(find.text('−50,00 MXN'), findsWidgets);
    expect(find.textContaining('Poko fèmen kès jodi a: Wesner'), findsOneWidget);
    expect(find.text('Nòt ajan an: Monnen bay pa erè'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Valide'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Valide').last);
    await tester.pumpAndSettle();
    expect(cash.decisions, ['validate:CK_1']);
  });
}
