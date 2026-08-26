import 'package:shared_preferences/shared_preferences.dart';
class ApiConfig {
  ApiConfig._();
  static final ApiConfig instance = ApiConfig._();

  static const _prefsKey = 'base_url';
  static const defaultBaseUrl = 'http://62.109.2.230';

  String baseUrl = defaultBaseUrl;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_prefsKey) ?? defaultBaseUrl;
  }

  Future<void> setBaseUrl(String url) async {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (cleaned.isEmpty) cleaned = defaultBaseUrl;
    baseUrl = cleaned;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, baseUrl);
  }

  /// Derives the ws:// or wss:// URL (without query string) from baseUrl.
  String get wsUrl {
    final uri = Uri.parse(baseUrl);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.authority}/ws';
  }

  /// Resolves a possibly-relative media path (e.g. "/media/avatars/x.jpg")
  /// returned by the API into a fully qualified URL.
  String resolveMediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$baseUrl$path';
  }
}
