import 'package:flutter/material.dart';
import 'package:mon_premye_app/app/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final router = buildRouter();

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'VOUPVAPCASH',
      routerConfig: router,
    );
  }
}
