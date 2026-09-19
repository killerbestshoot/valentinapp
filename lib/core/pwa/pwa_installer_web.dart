import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'pwa_installer.dart';

// Fonksyon sa yo soti nan ti script ki nan `web/index.html`. Se la
// `beforeinstallprompt` kenbe, paske li rive anvan Flutter fin demare.
@JS('pwaMode')
external JSString _jsMode();

@JS('pwaOnChange')
external void _jsOnChange(JSFunction callback);

@JS('pwaPrompt')
external JSPromise<JSString> _jsPrompt();

PwaInstaller createPwaInstaller() => _WebPwaInstaller();

class _WebPwaInstaller implements PwaInstaller {
  final ValueNotifier<PwaInstallMode> _mode =
      ValueNotifier<PwaInstallMode>(PwaInstallMode.none);

  @override
  ValueListenable<PwaInstallMode> get mode => _mode;

  @override
  void start() {
    _refresh();

    try {
      _jsOnChange(_refresh.toJS);
    } catch (_) {
      // Ansyen `index.html` nan kach navigatè a: pa gen relè a. Nou pa
      // pwopoze anyen olye nou kraze app la.
    }
  }

  void _refresh() {
    try {
      _mode.value = switch (_jsMode().toDart) {
        'prompt' => PwaInstallMode.prompt,
        'manual' => PwaInstallMode.manual,
        _ => PwaInstallMode.none,
      };
    } catch (_) {
      _mode.value = PwaInstallMode.none;
    }
  }

  @override
  Future<bool> promptInstall() async {
    try {
      final outcome = (await _jsPrompt().toDart).toDart;
      _refresh();
      return outcome == 'accepted';
    } catch (_) {
      _refresh();
      return false;
    }
  }

  @override
  void dispose() => _mode.dispose();
}
