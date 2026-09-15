class ApiBase {
  /// URL backend la.
  ///
  /// Default la se serveur dev lokal la — MENM PÒ ak `server/.env` (PORT=4500).
  /// Si de valè sa yo pa dakò, app la rele yon pò kote pa gen anyen epi ou wè
  /// "Nou pa rive jwenn serveur a".
  ///
  /// Pou yon lòt anviwònman:
  ///   flutter run --dart-define=API_BASE_URL=https://api.voupvapcash.com
  ///
  /// Yon valè VID (`--dart-define=API_BASE_URL=`) vle di "menm orijin ak paj
  /// la": se sa imaj Docker la fè, nginx voye `/api` bay serveur a. Konsa
  /// menm imaj la mache sou nenpòt domèn san rekonpile.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4500',
  );

  /// URL efektif la. Sou mobil `baseUrl` dwe absoli: pa gen "paj" pou rezoud
  /// yon orijin.
  static String get origin => baseUrl.isEmpty ? Uri.base.origin : baseUrl;

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 25);

  static Uri uri(String path, {Map<String, dynamic>? query}) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$origin$cleanPath').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v.toString())),
    );
  }
}
