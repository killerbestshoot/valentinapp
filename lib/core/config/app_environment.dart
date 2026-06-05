class AppEnvironment {
  AppEnvironment._();

  static const mockFirebase = bool.fromEnvironment('MOCK_FIREBASE');
}
