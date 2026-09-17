import 'package:flutter/material.dart';
import 'package:mon_premye_app/app/app_router.dart';
import 'package:mon_premye_app/core/session/session_timeout_guard.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'VOUPVAPCASH',
      routerConfig: router,
      // Gad la anvlope tout ekran yo: se sèl fason pou konte inaktivite a
      // menm jan sou chak paj. Li dwe rete anndan `MaterialApp` pou l
      // siviv chanjman wout.
      builder: (context, child) => SessionTimeoutGuard(
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
