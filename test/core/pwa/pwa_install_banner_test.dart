import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mon_premye_app/core/pwa/pwa_install_banner.dart';
import 'package:mon_premye_app/core/pwa/pwa_installer.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePwaInstaller implements PwaInstaller {
  _FakePwaInstaller(PwaInstallMode mode)
      : _mode = ValueNotifier<PwaInstallMode>(mode);

  final ValueNotifier<PwaInstallMode> _mode;
  int startCount = 0;
  int promptCount = 0;
  bool accepts = true;

  @override
  ValueListenable<PwaInstallMode> get mode => _mode;

  @override
  void start() => startCount += 1;

  @override
  Future<bool> promptInstall() async {
    promptCount += 1;
    if (accepts) _mode.value = PwaInstallMode.none;
    return accepts;
  }

  void becomeInstallable() => _mode.value = PwaInstallMode.prompt;

  @override
  void dispose() => _mode.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<_FakePwaInstaller> pump(
    WidgetTester tester, {
    PwaInstallMode mode = PwaInstallMode.prompt,
  }) async {
    final installer = _FakePwaInstaller(mode);
    addTearDown(installer.dispose);

    await tester.pumpWidget(MaterialApp(
      home: PwaInstallBanner(
        installer: installer,
        child: const Scaffold(body: Center(child: Text('tablo'))),
      ),
    ));
    await tester.pumpAndSettle();

    return installer;
  }

  testWidgets('pwopoze enstalasyon an lè navigatè a ka fè l', (tester) async {
    final installer = await pump(tester);

    expect(find.text('Enstale VOUPVAPCASH'), findsOneWidget);
    expect(find.text('Enstale'), findsOneWidget);
    expect(installer.startCount, 1);
    expect(find.text('tablo'), findsOneWidget, reason: 'ekran an rete vizib');
  });

  testWidgets('pa pwopoze anyen sou app natif yo', (tester) async {
    await pump(tester, mode: PwaInstallMode.none);

    expect(find.text('Enstale VOUPVAPCASH'), findsNothing);
  });

  testWidgets('sou Safari iOS li bay chemen an, san bouton Enstale',
      (tester) async {
    await pump(tester, mode: PwaInstallMode.manual);

    expect(find.textContaining('Sou ekran dakèy'), findsOneWidget);
    expect(find.text('Enstale'), findsNothing,
        reason: 'Safari pa gen dyalòg: yon bouton ta bay manti');
    expect(find.text('Konprann'), findsOneWidget);
  });

  testWidgets('bouton Enstale a louvri dyalòg navigatè a', (tester) async {
    final installer = await pump(tester);

    await tester.tap(find.text('Enstale'));
    await tester.pumpAndSettle();

    expect(installer.promptCount, 1);
    expect(find.text('Enstale VOUPVAPCASH'), findsNothing,
        reason: 'app la enstale: pa gen rezon pwopoze ankò');
  });

  testWidgets('« Pita » fèmen l pou tout bon', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Pita'));
    await tester.pumpAndSettle();

    expect(find.text('Enstale VOUPVAPCASH'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('voupvapcash.pwa.dismissed'), isTrue);
  });

  testWidgets('yon refi ki sove kenbe bandwòl la fèmen apre redemaraj',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'voupvapcash.pwa.dismissed': true,
    });

    await pump(tester);

    expect(find.text('Enstale VOUPVAPCASH'), findsNothing);
  });

  testWidgets('bandwòl la parèt lè navigatè a chanje davi an wout',
      (tester) async {
    final installer = await pump(tester, mode: PwaInstallMode.none);
    expect(find.text('Enstale VOUPVAPCASH'), findsNothing);

    // `beforeinstallprompt` ka rive apre app la fin demare.
    installer.becomeInstallable();
    await tester.pumpAndSettle();

    expect(find.text('Enstale VOUPVAPCASH'), findsOneWidget);
  });
}
