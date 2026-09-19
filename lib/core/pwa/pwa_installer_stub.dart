import 'package:flutter/foundation.dart';

import 'pwa_installer.dart';

/// Sou Android, iOS ak desktop natif, app la deja sou aparèy la: pa gen anyen
/// pou enstale. Se vèsyon sa a tès yo wè tou, paske yo kouri sou VM la.
PwaInstaller createPwaInstaller() => _NoopPwaInstaller();

class _NoopPwaInstaller implements PwaInstaller {
  final ValueNotifier<PwaInstallMode> _mode =
      ValueNotifier<PwaInstallMode>(PwaInstallMode.none);

  @override
  ValueListenable<PwaInstallMode> get mode => _mode;

  @override
  void start() {}

  @override
  Future<bool> promptInstall() async => false;

  @override
  void dispose() => _mode.dispose();
}
