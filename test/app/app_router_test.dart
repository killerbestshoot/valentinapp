import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/app/app_router.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._currentUser);

  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    _currentUser = AuthUser(uid: 'fake-user', email: email);
    _controller.add(_currentUser);
    return _currentUser!;
  }

  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) {
    return signIn(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required AuthUser? user,
    Widget? adminDashboard,
    Widget? ownerDashboard,
    Widget? agentDashboard,
  }) async {
    final auth = _FakeAuthRepository(user);
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: buildRouter(
          authRepository: auth,
          adminDashboard: adminDashboard,
          ownerDashboard: ownerDashboard,
          agentDashboard: agentDashboard,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('redirects logged-in owner to owner dashboard', (tester) async {
    await pumpApp(
      tester,
      user: const AuthUser(
        uid: 'owner-1',
        email: 'owner@example.test',
        role: AppRole.owner,
      ),
      ownerDashboard: const Scaffold(
        body: Center(child: Text('Owner command center')),
      ),
    );

    expect(find.text('Owner command center'), findsOneWidget);
  });

  testWidgets('redirects logged-in admin to admin dashboard', (tester) async {
    await pumpApp(
      tester,
      user: const AuthUser(
        uid: 'admin-1',
        email: 'admin@example.test',
        role: AppRole.admin,
      ),
      adminDashboard: const Scaffold(
        body: Center(child: Text('Admin dashboard')),
      ),
    );

    expect(find.text('Admin dashboard'), findsOneWidget);
  });

  testWidgets('shows green login screen when signed out', (tester) async {
    await pumpApp(tester, user: null);

    expect(find.text('VOUPVAPCASH'), findsOneWidget);
    expect(find.text('Konekte'), findsWidgets);
  });

  testWidgets('redirects logged-in agent to green agent dashboard',
      (tester) async {
    await pumpApp(
      tester,
      user: const AuthUser(
        uid: 'agent-1',
        email: 'agent@example.test',
        role: AppRole.agent,
      ),
      agentDashboard: const Scaffold(
        body: Center(child: Text('Agent workspace')),
      ),
    );

    expect(find.text('Agent workspace'), findsOneWidget);
  });
}
