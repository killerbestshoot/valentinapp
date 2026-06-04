// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

class LocalProfileStore {
  LocalProfileStore._();

  static final LocalProfileStore instance = LocalProfileStore._();

  static const _prefix = 'voupvapcash.localProfile.';

  Future<Map<String, dynamic>?> load(String authUid) async {
    final raw = html.window.localStorage[_prefix + authUid];
    if (raw == null || raw.trim().isEmpty) return null;

    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  Future<void> save(String authUid, Map<String, dynamic> profile) async {
    html.window.localStorage[_prefix + authUid] = jsonEncode(profile);
  }
}
