import 'dart:async';
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

  /// Same as [multipart], but reports upload progress via [onProgress]
  /// (bytesSent, totalBytes) as the request body is streamed out. Used to
  /// drive the progress bubble shown while a media message is uploading.
  Future<dynamic> multipartWithProgress(
    String path, {
    required String fieldName,
    required String filePath,
    String method = 'POST',
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = _uri(path);
    final inner = http.MultipartRequest(method, uri);
    inner.headers.addAll(_headers(json: false));
    final mimeType = lookupMimeType(filePath);
    inner.files.add(await http.MultipartFile.fromPath(
      fieldName,
      filePath,
      contentType: mimeType != null ? MediaType.parse(mimeType) : null,
    ));

    final tracked = _ProgressTrackedRequest.from(inner, onProgress);
    final client = http.Client();
    try {
      final streamed = await client.send(tracked);
      final resp = await http.Response.fromStream(streamed);
      return _handle(resp);
    } finally {
      client.close();
    }
  }
}

/// Wraps an already-finalized [http.MultipartRequest] byte stream so it
/// reports how many bytes have been read so far — reading from this stream
/// is exactly what `http.Client.send()` does while pushing the request body
/// over the socket, so counting bytes read is a faithful proxy for upload
/// progress.
///
/// IMPORTANT: `MultipartRequest.finalize()` is what computes the multipart
/// boundary and sets the real `Content-Type: multipart/form-data;
/// boundary=...` header — that header does not exist before finalize() runs.
/// So headers must be copied from [inner] AFTER calling [inner.finalize()],
/// not before, or the server receives a request it can't parse as
/// multipart at all (and never sees the file field).
class _ProgressTrackedRequest extends http.BaseRequest {
  final http.ByteStream _bodyStream;
  final int _contentLength;
  final void Function(int sent, int total)? _onProgress;

  _ProgressTrackedRequest._(
    String method,
    Uri url,
    Map<String, String> headers,
    this._bodyStream,
    this._contentLength,
    this._onProgress,
  ) : super(method, url) {
    this.headers.addAll(headers);
  }

  factory _ProgressTrackedRequest.from(
    http.MultipartRequest inner,
    void Function(int sent, int total)? onProgress,
  ) {
    // finalize() is synchronous: it computes the boundary, sets
    // inner.headers['content-type'] accordingly, and returns a lazy
    // ByteStream (the actual file isn't read until something listens to
    // this stream). Reading inner.headers right after is safe and correct.
    final stream = inner.finalize();
    final tracked = _ProgressTrackedRequest._(
      inner.method,
      inner.url,
      inner.headers,
      stream,
      inner.contentLength,
      onProgress,
    );
    tracked.persistentConnection = inner.persistentConnection;
    tracked.followRedirects = inner.followRedirects;
    tracked.maxRedirects = inner.maxRedirects;
    return tracked;
  }

  @override
  int get contentLength => _contentLength;

  @override
  http.ByteStream finalize() {
    super.finalize();
    var sent = 0;
    final transformed = _bodyStream.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (data, sink) {
          sent += data.length;
          _onProgress?.call(sent, _contentLength);
          sink.add(data);
        },
      ),
    );
    return http.ByteStream(transformed);
  }
}