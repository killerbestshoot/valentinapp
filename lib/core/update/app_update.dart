import 'package:flutter/foundation.dart';

import '../config/app_version.dart';
import '../network/api_client.dart';

/// Sa sèvè a di sou vèsyon app la (`/api/app/version` oswa yon 426).
class UpdateInfo {
  const UpdateInfo({
    required this.latestVersion,
    required this.minBuild,
    required this.downloadUrl,
    this.message = '',
  });

  final String latestVersion;
  final int minBuild;
  final String downloadUrl;
  final String message;

  factory UpdateInfo.fromJson(Map<String, dynamic> j) => UpdateInfo(
        latestVersion: '${j['latestVersion'] ?? ''}',
        minBuild: j['minBuild'] is num ? (j['minBuild'] as num).toInt() : 0,
        downloadUrl: '${j['downloadUrl'] ?? ''}',
        message: '${j['message'] ?? ''}',
      );
}

/// Mete ajou obligatwa: lè [required] pa `null`, app la bloke dèyè ekran
/// "Mete ajou" a (`UpdateGate`). Li pa janm tounen `null` poukont li — se sèl
/// yon nouvo vèsyon ki debloke l.
class AppUpdate {
  AppUpdate._();

  static final AppUpdate instance = AppUpdate._();

  final ValueNotifier<UpdateInfo?> required = ValueNotifier<UpdateInfo?>(null);

  /// Rele pa `ApiClient` lè sèvè a reponn 426 `app_outdated`.
  void block(UpdateInfo info) {
    required.value ??= info;
  }

  /// Verifye lè app la louvri, menm anvan koneksyon. Yon erè rezo pa bloke
  /// anyen: se 426 la sou chak apèl ki gad la.
  Future<void> check({ApiClient? client}) async {
    try {
      final json = await (client ?? ApiClient.instance).get('/api/app/version');
      final info = UpdateInfo.fromJson(json);
      if (appBuild < info.minBuild) block(info);
    } catch (_) {}
  }

  @visibleForTesting
  void reset() => required.value = null;
}
