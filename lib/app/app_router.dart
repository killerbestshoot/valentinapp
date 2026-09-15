import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/payments/presentation/pages/send_money_page.dart';
import 'package:mon_premye_app/pages/dashboard/agent_dashboard.dart';
import 'package:mon_premye_app/pages/dashboard/home_page.dart';
import 'package:mon_premye_app/pages/auth/login_page.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

GoRouter buildRouter({
  AuthRepository? authRepository,
  Widget? adminDashboard,
  Widget? ownerDashboard,
  Widget? agentDashboard,
}) {
  final auth = authRepository ?? AuthRepositoryProvider.instance;

  bool isProtected(String loc) {
    return loc == '/dashboard' ||
        loc == '/owner' ||
        loc == '/admin' ||
        loc == '/send-money';
  }

  /// Ki wòl ki gen dwa sou chak wout.
  ///
  /// Serveur a deja refize done yo, men san sa yon ajan ki tape `/admin` nan
  /// bar adrès la ta ateri sou ekran admin nan — plen erè, e li ta wè estrikti
  /// aplikasyon an. Wout la dwe refize l anvan.
  const roleGuards = <String, Set<AppRole>>{
    '/admin': {AppRole.owner, AppRole.admin},
    '/owner': {AppRole.owner},
  };

  String homeForCurrentUser() {
    final user = auth.currentUser;
    switch (user?.role) {
      case null:
        return '/';
      case AppRole.owner:
        return '/owner';
      case AppRole.admin:
        return '/admin';
      case AppRole.agent:
      case AppRole.client:
        return '/dashboard';
    }
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loc = state.matchedLocation;

      if (!loggedIn && isProtected(loc)) return '/';

      if (loggedIn && (loc == '/' || loc == '/login' || loc == '/register')) {
        return homeForCurrentUser();
      }

      // Wòl la pa ase wo pou wout sa a: nou voye moun nan lakay li.
      final allowed = roleGuards[loc];
      final role = auth.currentUser?.role;

      if (loggedIn && allowed != null && !allowed.contains(role)) {
        return homeForCurrentUser();
      }

      return null;
    },
    routes: [
      GoRoute(
          path: '/',
          builder: (context, state) =>
              LoginPage(authRepository: authRepository)),
      GoRoute(
          path: '/login',
          builder: (context, state) =>
              LoginPage(authRepository: authRepository)),
      GoRoute(
          path: '/register',
          builder: (context, state) =>
              LoginPage(authRepository: authRepository)),
      GoRoute(
          path: '/dashboard',
          builder: (context, state) =>
              agentDashboard ?? const AgentDashboard()),
      // Owner an sèvi ak menm tablo bò jesyon ak admin nan: tout tuil yo
      // (payout, komisyon, sèvis, sante...) chita sou SQLite. Ansyen
      // `OwnerDashboard` la te gen 21 tuil sou Firebase, mwatye ladan yo
      // doub ekran ki deja migre.
      GoRoute(
          path: '/owner',
          builder: (context, state) =>
              ownerDashboard ?? const HomePage()),
      GoRoute(
          path: '/admin',
          builder: (context, state) => adminDashboard ?? const HomePage()),
      GoRoute(
        path: '/send-money',
        builder: (context, state) {
          // `tx` prezan lè nou livre yon tranzaksyon ki deja egziste.
          final txId = state.uri.queryParameters['tx'] ?? '';
          return SendMoneyPage(
            kind: txId.isEmpty ? 'payout' : 'delivery',
            txId: txId,
          );
        },
      ),
    ],
  );
}
