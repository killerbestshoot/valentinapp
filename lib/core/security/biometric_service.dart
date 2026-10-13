import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../network/api_client.dart';
import '../../features/auth/data/http_auth_repository.dart';
import '../../features/auth/models/auth_user.dart';

/// Byometri (anprent, figi — oswa kòd telefòn nan si pa gen byometri).
///
/// KONEKSYON: telefòn nan pa janm kenbe modpas la. Lè moun nan aktive l, sèvè a
/// bay yon kle aparèy (`/api/auth/biometric/enroll`) ke nou mete nan kofrefò
/// Android la. Pou konekte, nou mande anprent lan, epi nou voye kle a.
/// Chanjman modpas / dezaktivasyon kont lan revoke kle a sou sèvè a.
///
/// OTORIZASYON: si l aktive, chak operasyon lajan (voye, apwouve, ajoute fon…)
/// mande anprent lan anvan li pati ([confirm]).
class BiometricService {
  BiometricService({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  static BiometricService instance = BiometricService();

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  static const _kDevice = 'bio.deviceId';
  static const _kSecret = 'bio.secret';
  static const _kEmail = 'bio.email';
  static const _kConfirm = 'bio.confirmOps';

  /// Koneksyon byometrik aktive sou aparèy sa a.
  final ValueNotifier<bool> loginEnabled = ValueNotifier(false);

  /// Imel kont ki aktive l (pou montre sou ekran koneksyon an).
  final ValueNotifier<String?> loginEmail = ValueNotifier(null);

  /// Mande anprent anvan operasyon lajan yo.
  final ValueNotifier<bool> confirmOperations = ValueNotifier(false);

  /// Li sa ki nan kofrefò a (lè app la louvri). Web: pa gen byometri.
  Future<void> load() async {
    if (kIsWeb) return;
    try {
      loginEnabled.value = (await _storage.read(key: _kDevice)) != null;
      loginEmail.value = await _storage.read(key: _kEmail);
      confirmOperations.value = (await _storage.read(key: _kConfirm)) == 'true';
    } catch (_) {}
  }

  /// Aparèy la gen byometri (oswa yon kòd/fòm) moun nan ka itilize.
  Future<bool> available() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported() && (await _auth.canCheckBiometrics || await _auth.isDeviceSupported());
    } catch (_) {
      return false;
    }
  }

  /// Mande anprent/figi (oswa kòd telefòn nan). `false` = anile oswa echwe.
  Future<bool> authenticate(String reason) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }

  /// Aktive koneksyon byometrik pou kont ki konekte a.
  Future<void> enableLogin({required String email, String label = ''}) async {
    if (!await authenticate('Konfime pou aktive koneksyon ak anprent')) {
      throw const ApiException('biometric_cancelled', 'Byometri a anile.');
    }
    final json = await ApiClient.instance.post('/api/auth/biometric/enroll', {'label': label});
    await _storage.write(key: _kDevice, value: '${json['deviceId']}');
    await _storage.write(key: _kSecret, value: '${json['secret']}');
    await _storage.write(key: _kEmail, value: email);
    loginEnabled.value = true;
    loginEmail.value = email;
  }

  /// Dezaktive l: kle a efase sou telefòn nan ak sou sèvè a.
  Future<void> disableLogin() async {
    final deviceId = await _storage.read(key: _kDevice);
    if (deviceId != null) {
      try {
        await ApiClient.instance.delete('/api/auth/biometric/$deviceId');
      } catch (_) {}
    }
    await _clearLogin();
  }

  Future<void> _clearLogin() async {
    await _storage.delete(key: _kDevice);
    await _storage.delete(key: _kSecret);
    await _storage.delete(key: _kEmail);
    loginEnabled.value = false;
    loginEmail.value = null;
  }

  /// Konekte ak anprent. `null` = moun nan anile.
  Future<AuthUser?> signIn() async {
    final deviceId = await _storage.read(key: _kDevice);
    final secret = await _storage.read(key: _kSecret);
    if (deviceId == null || secret == null) {
      await _clearLogin();
      throw const ApiException('biometric_revoked', 'Koneksyon byometrik la pa aktive sou telefòn sa a.');
    }
    if (!await authenticate('Konekte nan VOUPVAPCASH')) return null;
    try {
      return await HttpAuthRepository.instance.signInWithBiometricKey(deviceId: deviceId, secret: secret);
    } on ApiException catch (err) {
      // Kle a revoke (modpas chanje, kont dezaktive): pa kite yon bouton ki p ap janm mache.
      if (err.code == 'biometric_revoked' || err.code == 'account_disabled') await _clearLogin();
      rethrow;
    }
  }

  /// Aktive / dezaktive konfimasyon operasyon yo (anprent mande pou chanje l).
  Future<bool> setConfirmOperations(bool value) async {
    if (!await authenticate(value ? 'Aktive otorizasyon byometrik' : 'Dezaktive otorizasyon byometrik')) {
      return false;
    }
    await _storage.write(key: _kConfirm, value: '$value');
    confirmOperations.value = value;
    return true;
  }

  /// Gad operasyon lajan: `true` si otorizasyon an pa aktive, oswa si anprent
  /// la konfime. Sèvi ak li anvan voye, apwouve oswa ajoute fon.
  Future<bool> confirm(String reason) async {
    if (kIsWeb || !confirmOperations.value) return true;
    return authenticate(reason);
  }
}
