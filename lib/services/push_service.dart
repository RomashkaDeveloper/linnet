import 'dart:io';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Handles the /push/* endpoints.
///
/// NOTE: the backend expects a real Firebase Cloud Messaging device token
/// (see docs.md — the server pushes through FCM when a chat member is
/// offline). Wiring up actual FCM requires adding the `firebase_messaging`
/// package plus a Firebase project (google-services.json /
/// GoogleService-Info.plist), which is a separate setup step outside this
/// codebase. To keep push registration functional end-to-end without that
/// setup, this service generates and persists a stable local token and
/// registers/unregisters it with the backend. Swap `_getOrCreateLocalToken`
/// for `FirebaseMessaging.instance.getToken()` once Firebase is wired up.
class PushService {
  static const _tokenKey = 'push_device_token';

  Future<String> _getOrCreateLocalToken() async {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(_tokenKey);
    if (token == null) {
      final rnd = Random.secure();
      token = List.generate(48, (_) => rnd.nextInt(16).toRadixString(16)).join();
      await prefs.setString(_tokenKey, token);
    }
    return token;
  }

  String get _platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  Future<void> register() async {
    try {
      final token = await _getOrCreateLocalToken();
      await ApiClient.instance.post('/push/register', body: {
        'token': token,
        'platform': _platform,
      });
    } catch (_) {
      // Push регистрация не критична для работы мессенджера — молча игнорируем.
    }
  }

  Future<void> unregister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token == null) return;
      await ApiClient.instance.delete('/push/unregister', body: {'token': token});
    } catch (_) {}
  }

  Future<bool> status() async {
    try {
      final data = await ApiClient.instance.get('/push/status');
      if (data is Map && data['enabled'] is bool) return data['enabled'] as bool;
      if (data is bool) return data;
      return false;
    } catch (_) {
      return false;
    }
  }
}
