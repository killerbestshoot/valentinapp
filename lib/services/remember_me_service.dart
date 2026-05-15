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

  RememberMeState _state = const RememberMeState(
    rememberMe: false,
    email: '',
  );

  Future<RememberMeState> load() async {
    return _state;
  }

  Future<void> save({
    required bool rememberMe,
    required String email,
  }) async {
    _state = RememberMeState(
      rememberMe: rememberMe,
      email: rememberMe ? email.trim() : '',
    );
  }
}
