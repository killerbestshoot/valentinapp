import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mon_premye_app/core/models/app_role.dart';
import 'package:mon_premye_app/features/auth/data/auth_repository_provider.dart';
import 'package:mon_premye_app/features/auth/domain/auth_repository.dart';
import 'package:mon_premye_app/features/owner/legacy/owner_dashboard.dart';
import 'package:mon_premye_app/features/services/presentation/pages/countries_screen.dart';
import 'package:mon_premye_app/features/transactions/presentation/pages/new_transaction_screen.dart';
import 'package:mon_premye_app/features/transactions/presentation/pages/transactions_list_screen.dart';
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
        loc == '/countries' ||
        loc == '/tx/new' ||
        loc == '/tx/list';
  }

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
      GoRoute(
          path: '/owner',
          builder: (context, state) =>
              ownerDashboard ?? const OwnerDashboard()),
      GoRoute(
          path: '/admin',
          builder: (context, state) => adminDashboard ?? const HomePage()),
      GoRoute(
          path: '/countries',
          builder: (context, state) => const CountriesScreen()),
      GoRoute(
        path: '/tx/new',
        builder: (context, state) {
          final svc = state.uri.queryParameters['service'];
          return NewTransactionScreen(initialService: svc);
        },
      ),
      GoRoute(
          path: '/tx/list',
          builder: (context, state) => const TransactionsListScreen()),
    ],
  );
}
