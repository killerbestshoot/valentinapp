import 'package:shared_preferences/shared_preferences.dart';

class RememberMeState {
  const RememberMeState({
    required this.rememberMe,
    required this.email,
  });

  final bool rememberMe;
  final String email;
}

class RememberMeService {
  RememberMeService._();

  static final RememberMeService instance = RememberMeService._();

  static const _rememberKey = 'auth.remember_me';
  static const _emailKey = 'auth.remembered_email';

  Future<RememberMeState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberKey) ?? false;
    final email = rememberMe ? (prefs.getString(_emailKey) ?? '') : '';

    return RememberMeState(
      rememberMe: rememberMe,
      email: email,
    );
  }

  Future<void> save({
    required bool rememberMe,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rememberKey, rememberMe);

    if (rememberMe) {
      await prefs.setString(_emailKey, email.trim());
    } else {
      await prefs.remove(_emailKey);
    }
  }
}
