import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/app/admin_shell.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/core/network/api_client.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';
import 'package:mon_premye_app/features/operations/data/operations_api.dart';
import 'package:mon_premye_app/widgets/dashboard_ui.dart';

class _FakeSystemApi extends SystemApi {
  _FakeSystemApi() : super(client: ApiClient());

  @override
  Future<List<AppNotification>> notifications() async =>
      const [AppNotification(type: 'payouts', severity: 'warning', title: '3 payout', count: 3)];
}

void main() {
  setUp(() => SystemApi.override(_FakeSystemApi()));
  tearDown(() {
    SystemApi.reset();
    AuthRepositoryProvider.reset();
  });

  Widget shell({VoidCallback? onCreate}) => MaterialApp(
        home: AdminShell(
          onCreateTransaction: onCreate ?? () {},
          destinations: [
            ShellDestination(id: 'dashboard', label: 'Tablo', icon: Icons.dashboard, builder: (_) => const Text('PAJ TABLO')),
            ShellDestination(
              id: 'transactions',
              label: 'Tranzaksyon',
              icon: Icons.receipt,
              section: 'Operasyon',
              builder: (_) => const DashboardPage(title: 'Transactions', children: [Text('PAJ TRANZAKSYON')]),
            ),
            ShellDestination(id: 'notifications', label: 'Notifikasyon', icon: Icons.notifications, section: 'Sistèm', badge: true, builder: (_) => const Text('PAJ NOTIF')),
            ShellDestination(id: 'settings', label: 'Paramèt', icon: Icons.settings, section: 'Sistèm', builder: (_) => const Text('PAJ PARAMÈT')),
          ],
        ),
      );

  testWidgets('gwo ekran: meni bò a, non moun nan, chanje paj san ba doub', (tester) async {
    AuthRepositoryProvider.override(_FakeAuth());
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var created = 0;
    await tester.pumpWidget(shell(onCreate: () => created++));
    await tester.pumpAndSettle();

    expect(find.text('PAJ TABLO'), findsOneWidget);
    expect(find.text('Marie Owner'), findsWidgets, reason: 'non moun ki konekte a');
    expect(find.text('Pwopriyetè'), findsOneWidget);
    expect(find.text('OPERASYON'), findsOneWidget);
    expect(find.text('3'), findsWidgets, reason: 'badj notifikasyon');

    await tester.tap(find.text('Tranzaksyon'));
    await tester.pumpAndSettle();
    expect(find.text('PAJ TRANZAKSYON'), findsOneWidget);
    expect(find.byType(AppBar), findsNothing, reason: 'kad la montre tit la, paj la pa ajoute yon ba');

    await tester.tap(find.text('Nouvo tranzaksyon'));
    expect(created, 1);
  });

  testWidgets('telefòn: meni an nan yon tiwa', (tester) async {
    AuthRepositoryProvider.override(_FakeAuth());
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();

    expect(find.text('Paramèt'), findsNothing);
    await tester.tap(find.byTooltip('Meni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paramèt'));
    await tester.pumpAndSettle();
    expect(find.text('PAJ PARAMÈT'), findsOneWidget);
  });
}

class _FakeAuth implements AuthRepository {
  @override
  AuthUser? get currentUser => const AuthUser(
        uid: 'u1',
        email: 'marie@exemple.com',
        role: AppRole.owner,
        displayName: 'Marie Owner',
        enterpriseName: 'Transfè Lakay',
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
