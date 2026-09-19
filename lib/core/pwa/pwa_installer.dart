import 'package:flutter/foundation.dart';

import 'pwa_installer_stub.dart'
    if (dart.library.js_interop) 'pwa_installer_web.dart' as impl;

/// Sa navigatè a ka fè pou enstale app la sou aparèy la.
enum PwaInstallMode {
  /// Pa gen anyen pou pwopoze: app natif, navigatè ki pa sipòte sa, oswa app
  /// la deja enstale.
  none,

  /// Navigatè a ka louvri bwat dyalòg enstalasyon li menm (Chrome, Edge).
  prompt,

  /// Safari iOS: pa gen dyalòg. Se moun nan ki dwe pase pa meni Pataje a.
  manual,
}

/// Pwopozisyon enstalasyon an (PWA).
///
/// Sou app natif yo pa gen anyen pou fè: [createPwaInstaller] bay yon vèsyon
/// ki pa janm pwopoze anyen. Se sèl bò web la ki pale ak navigatè a.
abstract class PwaInstaller {
  /// Ki sa nou ka pwopoze kounye a. Li chanje lè navigatè a fè nou konnen.
  ValueListenable<PwaInstallMode> get mode;

  /// Kòmanse koute navigatè a.
  void start();

  /// Louvri bwat dyalòg navigatè a. Retounen vre si moun nan aksepte.
  ///
  /// Dwe soti nan yon vre jès moun nan: navigatè yo refize l otreman.
  Future<bool> promptInstall();

  void dispose();
}

PwaInstaller createPwaInstaller() => impl.createPwaInstaller();
