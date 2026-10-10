import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';
import 'package:mon_premye_app/features/operations/data/reconciliation_api.dart';
import 'package:mon_premye_app/pages/system/stuck_transfers_page.dart';

class _FakeApi extends ReconciliationApi {
  _FakeApi() : super(client: ApiClient());

  final failed = <String>[];
  final delivered = <String, String>{};

  @override
  Future<List<StuckTransfer>> stuck() async => [
        if (!failed.contains('TRF_1') && !delivered.containsKey('TRF_1'))
          StuckTransfer.fromJson({
            'transferId': 'TRF_1', 'network': 'moncash', 'manualReview': true, 'amountHtg': 15276.22,
            'amount': 116.15, 'currency': 'USD', 'debit': 121.99, 'walletCurrency': 'USD',
            'phone': '+50948465325', 'receiverName': 'Junette', 'staffName': 'Valentin', 'txStatus': 'pending',
            'createdAt': DateTime(2026, 9, 20, 2, 18).millisecondsSinceEpoch,
          }),
      ];

  @override
  Future<void> markFailed(String transferId, {required String note}) async => failed.add(transferId);

  @override
  Future<void> confirmDelivered(String transferId, {required String gatewayId, required String note}) async =>
      delivered[transferId] = gatewayId;
}

class _Auth implements AuthRepository {
  _Auth(this.role);
  final AppRole role;

  @override
  AuthUser? get currentUser => AuthUser(uid: 'u', email: 'o@x.com', role: role, displayName: 'O');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeApi api;
  setUp(() {
    api = _FakeApi();
    ReconciliationApi.override(api);
  });
  tearDown(() {
    ReconciliationApi.reset();
    AuthRepositoryProvider.reset();
  });

  Future<void> pump(WidgetTester tester, AppRole role) async {
    AuthRepositoryProvider.override(_Auth(role));
    await tester.binding.setSurfaceSize(const Size(1000, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: StuckTransfersPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('owner: make echwe mande yon rezon, epi transfè a disparèt', (tester) async {
    await pump(tester, AppRole.owner);

    expect(find.text('15 276,22 HTG'), findsOneWidget);
    expect(find.text('Verifikasyon manyèl'), findsOneWidget);
    expect(find.text('Junette'), findsOneWidget);

    await tester.tap(find.text('Make echwe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make echwe epi ranbouse'));
    await tester.pumpAndSettle();
    expect(find.text('Omwen 5 karaktè.'), findsOneWidget, reason: 'pa gen desizyon san tras');
    expect(api.failed, isEmpty);

    await tester.enterText(find.byType(TextFormField).last, 'Pa sou dashboard Bazik');
    await tester.tap(find.text('Make echwe epi ranbouse'));
    await tester.pumpAndSettle();
    expect(api.failed, ['TRF_1']);
    expect(find.text('Pa gen transfè bloke.'), findsOneWidget);
  });

  testWidgets('owner: konfime livre mande ID Bazik la', (tester) async {
    await pump(tester, AppRole.owner);
    await tester.tap(find.text('Konfime livre'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'BZK_123');
    await tester.enterText(find.byType(TextFormField).last, 'Wè l sou dashboard');
    await tester.tap(find.widgetWithText(FilledButton, 'Konfime livre').last);
    await tester.pumpAndSettle();
    expect(api.delivered, {'TRF_1': 'BZK_123'});
  });

  testWidgets('admin wè lis la men li pa ka deside', (tester) async {
    await pump(tester, AppRole.admin);
    expect(find.text('15 276,22 HTG'), findsOneWidget);
    expect(find.text('Make echwe'), findsNothing);
    expect(find.text('Konfime livre'), findsNothing);
  });
}
