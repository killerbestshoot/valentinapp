import 'package:shared_preferences/shared_preferences.dart';

/// Kote jeton sesyon an rete.
///
/// Nou kenbe l an memwa pou apèl yo rapid, epi nou sove l sou aparèy la pou
/// moun nan pa bezwen konekte ankò chak fwa li rafrechi paj la.
///
/// Nou PA sove modpas la — jamè. Sèlman jeton an, ki gen yon dat ekspirasyon
/// e ke serveur a ka anile nenpòt lè.
class SessionStore {
  SessionStore._();

  static final SessionStore instance = SessionStore._();

  static const _tokenKey = 'voupvapcash.session.token';
  static const _expiresKey = 'voupvapcash.session.expiresAt';

  String? _token;
  int? _expiresAt;
  bool _loaded = false;

  String? get token {
    if (_expiresAt != null && DateTime.now().millisecondsSinceEpoch > _expiresAt!) {
      return null;
    }
    return _token;
  }

  bool get hasSession => token != null;

  /// Chaje jeton an ki te sove. Rele l yon fwa nan demaraj la.
  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      _expiresAt = prefs.getInt(_expiresKey);
    } catch (_) {
      // Si stokaj la pa disponib (navigatè prive...), nou travay an memwa.
      _token = null;
      _expiresAt = null;
    }

    _loaded = true;
  }

  Future<void> save(String token, {int? expiresAt}) async {
    _token = token;
    _expiresAt = expiresAt;
    _loaded = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      if (expiresAt != null) {
        await prefs.setInt(_expiresKey, expiresAt);
      } else {
        await prefs.remove(_expiresKey);
      }
    } catch (_) {
      // Memwa sèlman: sesyon an ap dire jiska paj la fèmen.
    }
  }

  Future<void> clear() async {
    _token = null;
    _expiresAt = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_expiresKey);
    } catch (_) {
      // Pa grav: memwa a deja vid.
    }
  }
}
