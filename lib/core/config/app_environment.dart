class AppEnvironment {
  AppEnvironment._();

  /// Mòd demonstrasyon san serveur: dépôt otantifikasyon ak pasrèl simile.
  ///
  ///     flutter run --dart-define=MOCK_FIREBASE=true
  ///
  /// (Non an rete pou pa kase kòmand ki egziste yo; li pa gen rapò ak Firebase
  /// ankò — backend la se SQLite.)
  static const mockFirebase = bool.fromEnvironment('MOCK_FIREBASE');
}
