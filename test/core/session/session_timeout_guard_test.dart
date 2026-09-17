import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/session/session_store.dart';
import 'package:mon_premye_app/core/session/session_timeout_guard.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository()
      : _currentUser = const AuthUser(uid: 'ajan', email: 'ajan@example.test');

  final _controller = StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;
  int signOutCount = 0;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUp({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {
    signOutCount += 1;
    _currentUser = null;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Revèy la ak minitè `pumpWidget` la avanse ansanm: `advance` deplase
  /// toude, san sa youn ta wè tan pase e lòt la non.
  Future<void> pumpGuard(
    WidgetTester tester, {
    required _FakeAuthRepository auth,
    required SessionStore session,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: SessionTimeoutGuard(
        authRepository: auth,
        sessionStore: session,
        checkEvery: const Duration(seconds: 1),
        child: const Scaffold(body: Center(child: Text('tablo'))),
      ),
    ));
  }

  testWidgets('dekonekte lè moun nan sispann navige', (tester) async {
    var clock = 1000;
    final session = SessionStore.forTests(clock: () => clock);
    await session.save('jeton', idleTimeoutMs: 60000);

    final auth = _FakeAuthRepository();
    addTearDown(auth.dispose);

    await pumpGuard(tester, auth: auth, session: session);

    clock += 59000;
    await tester.pump(const Duration(seconds: 1));
    expect(auth.currentUser, isNotNull, reason: 'anvan limit lan');

    clock += 2000;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(auth.signOutCount, 1);
    expect(auth.currentUser, isNull);
    expect(session.consumeTimeoutNotice(), isTrue,
        reason: 'paj koneksyon an dwe ka esplike poukisa');
  });

  testWidgets('yon dwèt sou ekran an kenbe sesyon an louvri', (tester) async {
    var clock = 1000;
    final session = SessionStore.forTests(clock: () => clock);
    await session.save('jeton', idleTimeoutMs: 60000);

    final auth = _FakeAuthRepository();
    addTearDown(auth.dispose);

    await pumpGuard(tester, auth: auth, session: session);

    // Kat fwa 40 s = 160 s an tou, men yon touche chak fwa.
    for (var i = 0; i < 4; i += 1) {
      clock += 40000;
      await tester.tap(find.text('tablo'));
      await tester.pump(const Duration(seconds: 1));
    }

    expect(auth.signOutCount, 0);
    expect(auth.currentUser, isNotNull);
  });

  testWidgets('gad la kite bouton yo resevwa touche yo', (tester) async {
    var clock = 1000;
    final session = SessionStore.forTests(clock: () => clock);
    await session.save('jeton', idleTimeoutMs: 60000);

    final auth = _FakeAuthRepository();
    addTearDown(auth.dispose);

    var tapped = 0;

    await tester.pumpWidget(MaterialApp(
      home: SessionTimeoutGuard(
        authRepository: auth,
        sessionStore: session,
        checkEvery: const Duration(seconds: 1),
        child: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => tapped += 1,
              child: const Text('Voye lajan'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Voye lajan'));
    await tester.pump();

    expect(tapped, 1, reason: 'gad la tande sèlman, li pa vale evènman yo');
  });

  testWidgets('pa dekonekte yon moun ki pa konekte', (tester) async {
    var clock = 1000;
    final session = SessionStore.forTests(clock: () => clock);

    final auth = _FakeAuthRepository();
    addTearDown(auth.dispose);
    await auth.signOut();
    auth.signOutCount = 0;

    await pumpGuard(tester, auth: auth, session: session);

    clock += 10 * 60 * 1000;
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(auth.signOutCount, 0);
  });
}
