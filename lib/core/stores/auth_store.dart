import 'package:flutter/foundation.dart';

class AuthStore extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  bool get isAuthenticated =>
      (_accessToken != null && _accessToken!.isNotEmpty);

  /// Si ou itilize Firebase, ou ka mete token Firebase la isit.
  Future<void> setAccessToken(String? token) async {
    _accessToken = token;
    notifyListeners();
  }

  Future<void> setTokens({String? accessToken, String? refreshToken}) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    notifyListeners();
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    notifyListeners();
  }
}

/// Instance global (senp) pou pwoj a.
/// Si ou deja gen DI/Provider, ou ka retire global sa a.
final authStore = AuthStore();
