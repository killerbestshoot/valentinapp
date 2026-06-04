import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import 'package:mon_premye_app/features/auth/presentation/pages/welcome_screen.dart';
import 'package:mon_premye_app/features/auth/presentation/pages/login_screen.dart';
import 'package:mon_premye_app/features/auth/presentation/pages/register_screen.dart';
import 'package:mon_premye_app/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:mon_premye_app/features/services/presentation/pages/countries_screen.dart';
import 'package:mon_premye_app/features/transactions/presentation/pages/new_transaction_screen.dart';
import 'package:mon_premye_app/features/transactions/presentation/pages/transactions_list_screen.dart';

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

GoRouter buildRouter() {
  final auth = FirebaseAuth.instance;

  bool isProtected(String loc) {
    return loc == '/dashboard' ||
        loc == '/countries' ||
        loc == '/tx/new' ||
        loc == '/tx/list';
  }

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) {
      final loggedIn = auth.currentUser != null;
      final loc = state.matchedLocation;

      if (!loggedIn && isProtected(loc)) return '/';
      if (loggedIn && (loc == '/' || loc == '/login' || loc == '/register')) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen()),
      GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen()),
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
