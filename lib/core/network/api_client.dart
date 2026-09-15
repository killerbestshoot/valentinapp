import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_base.dart';
import '../session/session_store.dart';

/// Erè ki soti nan serveur a, ak yon kòd nou ka trete.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.status = 0});

  final String code;
  final String message;
  final int status;

  bool get isUnauthenticated => code == 'unauthenticated' || status == 401;
  bool get isForbidden => code == 'forbidden' || status == 403;

  @override
  String toString() => message;
}

/// Kliyan HTTP pou tout aplikasyon an.
///
/// Se sèl pòt antre done aplikasyon an: chak apèl pote
/// jeton sesyon an, epi erè yo tounen an `ApiException` ak yon kòd.
///
/// Yon sèl kote konnen:
///   - ki jan nou otantifye (jeton Bearer);
///   - ki jan yon erè serveur parèt;
///   - sa pou fè lè sesyon an tonbe (401 -> netwaye jeton an).
class ApiClient {
  ApiClient({http.Client? client, SessionStore? session})
      : _client = client ?? http.Client(),
        _session = session ?? SessionStore.instance;

  final http.Client _client;
  final SessionStore _session;

  static ApiClient? _instance;

  static ApiClient get instance => _instance ??= ApiClient();

  /// Pou tès yo.
  static void override(ApiClient client) => _instance = client;
  static void reset() => _instance = null;

  Map<String, String> _headers() {
    final token = _session.token;
    return {
      'content-type': 'application/json',
      if (token != null && token.isNotEmpty) 'authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _send(() => _client.get(
          ApiBase.uri(path, query: query),
          headers: _headers(),
        ));
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) {
    return _send(() => _client.post(
          ApiBase.uri(path),
          headers: _headers(),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? body]) {
    return _send(() => _client.patch(
          ApiBase.uri(path),
          headers: _headers(),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<Map<String, dynamic>> delete(String path) {
    return _send(() => _client.delete(ApiBase.uri(path), headers: _headers()));
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response response;

    try {
      response = await call().timeout(ApiBase.receiveTimeout);
    } catch (err) {
      // Nou di KI URL nou eseye: san sa, yon move pò bay menm mesaj ak yon
      // koneksyon ki koupe, e ou pa ka fè diferans lan.
      throw ApiException(
        'network_error',
        'Nou pa rive jwenn serveur a nan ${ApiBase.origin}. '
            'Verifye ke serveur a ap kouri.',
      );
    }

    Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException(
        'bad_response',
        'Serveur a voye yon repons nou pa konprann (${response.statusCode}).',
        status: response.statusCode,
      );
    }

    if (response.statusCode == 401) {
      // Sesyon an pa bon ankò: nou netwaye l pou app la mande koneksyon.
      await _session.clear();
    }

    if (response.statusCode >= 400 || json['ok'] != true) {
      throw ApiException(
        '${json['code'] ?? 'server_error'}',
        '${json['message'] ?? 'Yon erè rive sou serveur a.'}',
        status: response.statusCode,
      );
    }

    return json;
  }
}
