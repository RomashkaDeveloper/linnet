import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

// Handles the /push/* endpoints.
class PushService {
  static const _tokenKey = 'push_device_token';

  String get _platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  Future<void> register() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
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
