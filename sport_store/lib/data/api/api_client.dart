import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Тонкая обёртка над HTTP для общения с backend.
///
/// Используется реальными `Api*Repository`. Добавляет базовый URL, заголовки,
/// таймаут и разбор JSON. Аутентификация (токен) подставляется через [authToken].
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final http.Client _client;
  String? _authToken;

  /// Вызывается при изменении токена — для персиста JWT (см. main.dart).
  void Function(String? token)? onTokenChanged;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  String? get authToken => _authToken;
  set authToken(String? value) {
    _authToken = value;
    onTokenChanged?.call(value);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: query.map((k, v) => MapEntry(k, '$v')),
    );
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final res = await _client
        .get(_uri(path, query), headers: _headers)
        .timeout(ApiConfig.timeout);
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _client
        .post(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _decode(res);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final res = await _client
        .put(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await _client
        .patch(_uri(path), headers: _headers, body: jsonEncode(body))
        .timeout(ApiConfig.timeout);
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    throw ApiException(res.statusCode, res.body);
  }

  void close() => _client.close();
}
