import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const _tokenKey = 'access_token';
  static const _userKey = 'cached_user';

  Future<void> save(String token, UserPublic user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(
      _userKey,
      jsonEncode({
        'id': user.id,
        'username': user.username,
        'full_name': user.fullName,
        'bio': user.bio,
        'avatar_url': user.avatarUrl,
        'is_online': user.isOnline,
        'last_seen': user.lastSeen.toIso8601String(),
      }),
    );
  }

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<UserPublic?> readUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return UserPublic.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }
}
