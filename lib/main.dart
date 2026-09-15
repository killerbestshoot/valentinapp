import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/auth/data/http_auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si yon sesyon sove toujou bon, moun nan rete konekte san li pa retape
  // anyen. Backend la se serveur SQLite la (`server/`).
  await HttpAuthRepository.instance.restore();

  runApp(const App());
}
