import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mon_premye_app/core/security/biometric_service.dart';

class _FakeAuth extends LocalAuthentication {
  bool answer = true;
  final reasons = <String>[];

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    reasons.add(localizedReason);
    return answer;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('otorizasyon byometrik: pa aktive = pase; aktive = anprent obligatwa', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = _FakeAuth();
    final bio = BiometricService(auth: auth);

    expect(await bio.confirm('Konfime tranzaksyon an'), isTrue);
    expect(auth.reasons, isEmpty, reason: 'pa aktive: pa mande anyen');

    expect(await bio.setConfirmOperations(true), isTrue);
    expect(bio.confirmOperations.value, isTrue);

    auth.answer = false;
    expect(await bio.confirm('Konfime tranzaksyon an'), isFalse, reason: 'anprent anile: operasyon an bloke');
    auth.answer = true;
    expect(await bio.confirm('Konfime tranzaksyon an'), isTrue);

    // Paramèt la siviv yon redemaraj (kofrefò a).
    final reloaded = BiometricService(auth: auth);
    await reloaded.load();
    expect(reloaded.confirmOperations.value, isTrue);
  });

  test('dezaktive otorizasyon an mande anprent tou', () async {
    FlutterSecureStorage.setMockInitialValues({'bio.confirmOps': 'true'});
    final auth = _FakeAuth()..answer = false;
    final bio = BiometricService(auth: auth);
    await bio.load();
    expect(await bio.setConfirmOperations(false), isFalse);
    expect(bio.confirmOperations.value, isTrue, reason: 'yon moun ki pa ka konfime pa ka koupe l');
  });
}
