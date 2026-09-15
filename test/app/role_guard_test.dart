import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mon_premye_app/app/app_router.dart';
import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/auth/models/auth_user.dart';

/// Dépôt d'auth simulé: on fixe le rôle et on regarde où le routeur envoie.
class _FakeAuth implements AuthRepository {
  _FakeAuth(this._user);

  final AuthUser? _user;
  final _controller = StreamController<AuthUser?>.broadcast();

  @override
  AuthUser? get currentUser => _user;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AuthUser> signUp({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() async {}
}

AuthUser _user(AppRole role) =>
    AuthUser(uid: 'U1', email: 'x@example.com', role: role);

void main() {
  /// Ki wout moun nan ateri sou li reyèlman.
  Future<String> landingFor(WidgetTester tester, AppRole role, String target) async {
    final router = buildRouter(
      authRepository: _FakeAuth(_user(role)),
      adminDashboard: const Scaffold(body: Text('ADMIN')),
      ownerDashboard: const Scaffold(body: Text('OWNER')),
      agentDashboard: const Scaffold(body: Text('AGENT')),
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go(target);
    await tester.pumpAndSettle();

    return router.routerDelegate.currentConfiguration.uri.path;
  }

  testWidgets('yon ajan ki tape /admin ap voye lakay li', (tester) async {
    // Serveur a deja refize done yo, men ekran an pa dwe menm louvri.
    expect(await landingFor(tester, AppRole.agent, '/admin'), '/dashboard');
  });

  testWidgets('yon ajan ki tape /owner ap voye lakay li', (tester) async {
    expect(await landingFor(tester, AppRole.agent, '/owner'), '/dashboard');
  });

  testWidgets('yon admin pa ka antre nan /owner', (tester) async {
    expect(await landingFor(tester, AppRole.admin, '/owner'), '/admin');
  });

  testWidgets('yon admin antre nan /admin', (tester) async {
    expect(await landingFor(tester, AppRole.admin, '/admin'), '/admin');
  });

  testWidgets('yon owner antre toupatou', (tester) async {
    expect(await landingFor(tester, AppRole.owner, '/owner'), '/owner');
    expect(await landingFor(tester, AppRole.owner, '/admin'), '/admin');
  });

  testWidgets('yon kliyan pa ka antre nan ekran jesyon yo', (tester) async {
    expect(await landingFor(tester, AppRole.client, '/admin'), '/dashboard');
    expect(await landingFor(tester, AppRole.client, '/owner'), '/dashboard');
  });
}
