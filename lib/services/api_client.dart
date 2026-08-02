import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'api_config.dart';

/// Thrown for any non-2xx response. Carries the HTTP status code and a
/// human-readable message extracted from the API's error payload
/// (FastAPI-style `{"detail": ...}`).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;

  void setToken(String? token) => _token = token;
  String? get token => _token;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(ApiConfig.instance.baseUrl + path);
    if (query == null || query.isEmpty) return base;
    final stringQuery = <String, String>{};
    query.forEach((k, v) {
      if (v != null) stringQuery[k] = v.toString();
    });
    return base.replace(queryParameters: {
      ...base.queryParameters,
      ...stringQuery,
    });
  }

  Map<String, String> _headers({bool json = true}) {
    final h = <String, String>{};
    if (json) h['Content-Type'] = 'application/json';
    h['Accept'] = 'application/json';
    if (_token != null) h['Authorization'] = 'Bearer $_token';
    return h;
  }

  dynamic _handle(http.Response resp) {
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      if (resp.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(resp.bodyBytes));
      } catch (_) {
        return null;
      }
    }
    String message = 'Ошибка сервера (${resp.statusCode})';
    try {
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is Map && decoded['detail'] != null) {
        final d = decoded['detail'];
        if (d is String) {
          message = d;
        } else if (d is List) {
          message = d
              .map((e) => e is Map ? (e['msg']?.toString() ?? e.toString()) : e.toString())
              .join('; ');
        }
      }
    } catch (_) {
      // не-JSON тело ошибки — оставляем сообщение по умолчанию
    }
    throw ApiException(resp.statusCode, message);
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    final resp = await http.get(_uri(path, query), headers: _headers());
    return _handle(resp);
  }

  Future<dynamic> post(String path, {Object? body, Map<String, dynamic>? query}) async {
    final resp = await http.post(
      _uri(path, query),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(resp);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final resp = await http.patch(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(resp);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    final resp = await http.put(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(resp);
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    final resp = await http.delete(
      _uri(path),
      headers: _headers(),
      body: body != null ? jsonEncode(body) : null,
    );
    return _handle(resp);
  }

  /// Uploads a single file as multipart/form-data under [fieldName].
  /// Used for avatar upload and media messages.
  Future<dynamic> multipart(
    String path, {
    required String fieldName,
    required String filePath,
    String method = 'POST',
  }) async {
    final uri = _uri(path);
    final request = http.MultipartRequest(method, uri);
    request.headers.addAll(_headers(json: false));
    final mimeType = lookupMimeType(filePath);
    request.files.add(await http.MultipartFile.fromPath(
      fieldName,
      filePath,
      contentType: mimeType != null ? MediaType.parse(mimeType) : null,
    ));
    final streamed = await request.send();
    final resp = await http.Response.fromStream(streamed);
    return _handle(resp);
  }
}
