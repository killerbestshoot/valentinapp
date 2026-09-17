import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kote jeton sesyon an rete.
///
/// Nou kenbe l an memwa pou apèl yo rapid, epi nou sove l sou aparèy la pou
/// moun nan pa bezwen konekte ankò chak fwa li rafrechi paj la.
///
/// Nou PA sove modpas la — jamè. Sèlman jeton an, ki gen yon dat ekspirasyon
/// e ke serveur a ka anile nenpòt lè.
///
/// De bagay ka touye yon sesyon isit la:
///
///   - INAKTIVITE: si moun nan pa touche ekran an pandan [idleTimeout]
///     (5 minit), jeton an pa valab ankò. Se pwoteksyon prensipal la — yon
///     aparèy ki rete louvri sou yon kontwa pa ret konekte.
///   - EKSPIRASYON: dat serveur a bay nan koneksyon an.
///
/// Se `SessionTimeoutGuard` ki rele [touch] chak fwa moun nan navige.
class SessionStore {
  SessionStore._({int Function()? clock}) : _clock = clock ?? _systemClock;

  static final SessionStore instance = SessionStore._();

  /// Yon depo apa pou tès yo, ak yon revèy nou kontwole: limit lan se 5 minit,
  /// e okenn tès pa ka tann senk minit pou vre.
  @visibleForTesting
  factory SessionStore.forTests({int Function()? clock}) =>
      SessionStore._(clock: clock);

  /// Limit pa defo. Serveur a ka voye yon lòt nan koneksyon an.
  static const defaultIdleTimeout = Duration(minutes: 5);

  /// Nou pa ekri sou disk la nan chak touche dwèt: sa ta bat stokaj la pou
  /// anyen. An memwa limit lan egzat; sou disk li ka an reta [_persistEvery].
  static const _persistEvery = Duration(seconds: 15);

  static const _tokenKey = 'voupvapcash.session.token';
  static const _expiresKey = 'voupvapcash.session.expiresAt';
  static const _idleKey = 'voupvapcash.session.idleTimeoutMs';
  static const _lastSeenKey = 'voupvapcash.session.lastSeenAt';

  final int Function() _clock;

  String? _token;
  int? _expiresAt;
  int? _lastSeenAt;
  Duration _idleTimeout = defaultIdleTimeout;
  bool _loaded = false;
  int _persistedLastSeenAt = 0;

  /// Vre lè dènye sesyon an te fèmen pou inaktivite. Paj koneksyon an li l yon
  /// sèl fwa pou l esplike moun nan poukisa li dwe retape modpas li.
  bool _timedOut = false;

  /// Konbyen tan san navigasyon anvan sesyon an fèmen.
  Duration get idleTimeout => _idleTimeout;

  String? get token {
    if (isExpired || isIdle) return null;
    return _token;
  }

  bool get hasSession => token != null;

  /// Jeton an menm si li tonbe pou inaktivite.
  ///
  /// SÈL itilizasyon legitim: anile sesyon an sou serveur a. Pou nenpòt lòt
  /// apèl sèvi ak [token], ki respekte limit yo.
  String? get rawToken => _token;

  /// Vre si serveur a te bay yon dat ki deja pase.
  bool get isExpired {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return false;
    return _now() > expiresAt;
  }

  /// Vre si moun nan pa bay okenn siy navigasyon depi [idleTimeout].
  bool get isIdle {
    final lastSeenAt = _lastSeenAt;
    if (_token == null || lastSeenAt == null) return false;
    return _now() - lastSeenAt >= _idleTimeout.inMilliseconds;
  }

  /// Konbyen tan ki rete anvan dekoneksyon otomatik la.
  Duration get idleRemaining {
    final lastSeenAt = _lastSeenAt;
    if (_token == null || lastSeenAt == null) return _idleTimeout;

    final left = _idleTimeout.inMilliseconds - (_now() - lastSeenAt);
    return left <= 0 ? Duration.zero : Duration(milliseconds: left);
  }

  /// Chaje jeton an ki te sove. Rele l yon fwa nan demaraj la.
  ///
  /// Si app la te fèmen pandan plis pase [idleTimeout], sesyon an mouri isit
  /// la: relouvri app la apre yon bon ti tan pa dwe retounen sou tablo a.
  Future<void> load() async {
    if (_loaded) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      _expiresAt = prefs.getInt(_expiresKey);
      _lastSeenAt = prefs.getInt(_lastSeenKey);

      final idleMs = prefs.getInt(_idleKey);
      if (idleMs != null && idleMs > 0) {
        _idleTimeout = Duration(milliseconds: idleMs);
      }
    } catch (_) {
      // Si stokaj la pa disponib (navigatè prive...), nou travay an memwa.
      _token = null;
      _expiresAt = null;
      _lastSeenAt = null;
    }

    _loaded = true;

    // Jeton ki soti nan yon vèsyon app anvan limit lan pa gen `lastSeenAt`.
    // Nou kòmanse konte kounye a olye nou kite yo san limit.
    if (_token != null && _lastSeenAt == null) _lastSeenAt = _now();
    _persistedLastSeenAt = _lastSeenAt ?? 0;

    if (_token != null && (isExpired || isIdle)) {
      final wasIdle = isIdle;
      await clear();
      _timedOut = wasIdle;
    }
  }

  Future<void> save(
    String token, {
    int? expiresAt,
    int? idleTimeoutMs,
  }) async {
    _token = token;
    _expiresAt = expiresAt;
    _lastSeenAt = _now();
    _persistedLastSeenAt = _lastSeenAt!;
    _loaded = true;
    _timedOut = false;

    if (idleTimeoutMs != null && idleTimeoutMs > 0) {
      _idleTimeout = Duration(milliseconds: idleTimeoutMs);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setInt(_idleKey, _idleTimeout.inMilliseconds);
      await prefs.setInt(_lastSeenKey, _lastSeenAt!);
      if (expiresAt != null) {
        await prefs.setInt(_expiresKey, expiresAt);
      } else {
        await prefs.remove(_expiresKey);
      }
    } catch (_) {
      // Memwa sèlman: sesyon an ap dire jiska paj la fèmen.
    }
  }

  /// Make ke moun nan fèk navige: kontè 5 minit lan rekòmanse.
  ///
  /// Li pa fè anyen si sesyon an deja tonbe — san sa yon dènye evènman
  /// (yon dwèt sou ekran an) ta ka resisite yon sesyon ki ekspire.
  void touch() {
    if (_token == null || isExpired || isIdle) return;

    final current = _now();
    _lastSeenAt = current;

    if (current - _persistedLastSeenAt < _persistEvery.inMilliseconds) return;
    _persistedLastSeenAt = current;

    // Ekriti a pa bloke navigasyon an: li sèlman sèvi si app la redemare.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setInt(_lastSeenKey, current))
        .catchError((_) => false);
  }

  /// Rele lè nou fèmen sesyon an paske moun nan te rete san bouje.
  void markTimedOut() {
    _timedOut = true;
  }

  /// Retounen vre yon sèl fwa apre yon dekoneksyon pou inaktivite.
  bool consumeTimeoutNotice() {
    final value = _timedOut;
    _timedOut = false;
    return value;
  }

  Future<void> clear() async {
    _token = null;
    _expiresAt = null;
    _lastSeenAt = null;
    _persistedLastSeenAt = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_expiresKey);
      await prefs.remove(_lastSeenKey);
    } catch (_) {
      // Pa grav: memwa a deja vid.
    }
  }

  int _now() => _clock();

  static int _systemClock() => DateTime.now().millisecondsSinceEpoch;
}
