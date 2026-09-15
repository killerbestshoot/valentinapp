import 'dart:async';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_store.dart';
import '../domain/auth_repository.dart';
import '../models/auth_user.dart';

/// Otantifikasyon sou serveur SQLite la (ranplase Firebase Auth).
///
/// Diferans ki konte ak Firebase:
///   - kreye yon kont PA konekte moun ki kreye l la (se `UsersService` ki fè sa,
///     pa isit la);
///   - jeton an ak dat ekspirasyon l sove sou aparèy la, donk yon rafrechisman
///     paj pa dekonekte moun nan;
///   - serveur a ka anile yon sesyon nenpòt lè (chanjman modpas, dezaktivasyon).
class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository._();

  static final HttpAuthRepository instance = HttpAuthRepository._();

  final _controller = StreamController<AuthUser?>.broadcast();

  AuthUser? _currentUser;
  bool _restored = false;

  ApiClient get _api => ApiClient.instance;
  SessionStore get _session => SessionStore.instance;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  void _emit(AuthUser? user) {
    _currentUser = user;
    _controller.add(user);
  }

  /// Rele sa nan demaraj la: si jeton ki sove a toujou bon, moun nan rete
  /// konekte san li pa retape anyen.
  Future<AuthUser?> restore() async {
    if (_restored) return _currentUser;
    _restored = true;

    await _session.load();
    if (!_session.hasSession) return null;

    try {
      final json = await _api.get('/api/auth/me');
      final user = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
      _emit(user);
      return user;
    } on ApiException {
      // Jeton ekspire oswa anile: `ApiClient` deja netwaye l.
      _emit(null);
      return null;
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    final json = await _api.post('/api/auth/login', {
      'email': email,
      'password': password,
    });

    return _acceptSession(json);
  }

  /// Sou serveur SQLite la, yon moun pa ka kreye pwòp kont li: se yon admin ki
  /// kreye staff yo.
  ///
  /// SÈL eksepsyon an se premye demaraj la — `/bootstrap` kreye owner la ak
  /// antrepriz li, epi li refize mache apre sa.
  @override
  Future<AuthUser> signUp({
    required String email,
    required String password,
  }) async {
    final json = await _api.post('/api/auth/bootstrap', {
      'email': email,
      'password': password,
    });

    return _acceptSession(json);
  }

  Future<AuthUser> _acceptSession(Map<String, dynamic> json) async {
    final token = '${json['token'] ?? ''}';
    final expiresAt = json['expiresAt'];

    await _session.save(
      token,
      expiresAt: expiresAt is num ? expiresAt.toInt() : null,
    );

    final user = AuthUser.fromJson(json['user'] as Map<String, dynamic>);
    _emit(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    try {
      await _api.post('/api/auth/logout');
    } on ApiException {
      // Menm si serveur a pa reponn, nou dekonekte lokalman.
    }

    await _session.clear();
    _emit(null);
  }

  /// Chanje modpas. Tout sesyon yo tonbe: moun nan dwe konekte ankò.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post('/api/auth/change-password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });

    await _session.clear();
    _emit(null);
  }
}
