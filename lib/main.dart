import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/realtime/realtime.dart';
import 'core/security/biometric_service.dart';
import 'core/update/app_update.dart';
import 'features/auth/data/http_auth_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Si yon sesyon sove toujou bon, moun nan rete konekte san li pa retape
  // anyen. Backend la se serveur SQLite la (`server/`).
  await HttpAuthRepository.instance.restore();

  // Byometri: ki sa ki aktive sou telefòn sa a (kofrefò Android la).
  await BiometricService.instance.load();

  // Vèsyon minimòm: si app la twò ansyen, ekran "Mete ajou" a parèt touswit.
  // Pa tann: yon rezo ki lan pa dwe ralanti demaraj la (426 la ap kenbe l kanmenm).
  AppUpdate.instance.check();

  // Tan reyèl: ekran yo resevwa chanjman yo depi serveur a, san tann.
  Realtime.instance.enable();

  runApp(const App());
}
