import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/realtime/realtime.dart';
import 'features/auth/data/http_auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si yon sesyon sove toujou bon, moun nan rete konekte san li pa retape
  // anyen. Backend la se serveur SQLite la (`server/`).
  await HttpAuthRepository.instance.restore();

  // Tan reyèl: ekran yo resevwa chanjman yo depi serveur a, san tann.
  Realtime.instance.enable();

  runApp(const App());
}
