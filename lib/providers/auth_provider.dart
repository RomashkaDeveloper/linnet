import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart';
import '../services/token_storage.dart';
import '../services/socket_service.dart';
import '../services/push_service.dart';
import '../services/permission_service.dart';
import '../services/user_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  UserPublic? currentUser;
  String? errorMessage;
  bool isLoading = false;

  /// Called once on app start to restore a previous session from storage.
  Future<void> restore() async {
    final token = await TokenStorage.instance.readToken();
    final user = await TokenStorage.instance.readUser();
    if (token != null && user != null) {
      ApiClient.instance.setToken(token);
      currentUser = user;
      status = AuthStatus.authenticated;
      SocketService.instance.connect(token);
      unawaited(PushService().register());
      unawaited(AppPermissions.ensureNotifications());
      unawaited(_refreshMe());
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<void> _refreshMe() async {
    try {
      final me = await UserService().getMe();
      currentUser = me;
      final token = ApiClient.instance.token;
      if (token != null) await TokenStorage.instance.save(token, me);
      notifyListeners();
    } catch (_) {
      // офлайн или токен истёк — оставляем кэшированные данные
    }
  }

  Future<bool> login(String usernameOrEmail, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final tokenResp = await AuthService.instance
          .login(usernameOrEmail: usernameOrEmail, password: password);
      await _onAuthSuccess(tokenResp.accessToken, tokenResp.user);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register(
      String username, String email, String password, String? fullName) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final tokenResp = await AuthService.instance.register(
        username: username,
        email: email,
        password: password,
        fullName: fullName,
      );
      await _onAuthSuccess(tokenResp.accessToken, tokenResp.user);
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _onAuthSuccess(String token, UserPublic user) async {
    ApiClient.instance.setToken(token);
    currentUser = user;
    status = AuthStatus.authenticated;
    await TokenStorage.instance.save(token, user);
    SocketService.instance.connect(token);
    unawaited(PushService().register());
    unawaited(AppPermissions.ensureNotifications());
  }

  Future<void> logout() async {
    try {
      await AuthService.instance.logout();
    } catch (_) {}
    try {
      await PushService().unregister();
    } catch (_) {}
    SocketService.instance.disconnect();
    ApiClient.instance.setToken(null);
    await TokenStorage.instance.clear();
    currentUser = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> updateProfile({String? fullName, String? bio}) async {
    final updated = await UserService().updateMe(fullName: fullName, bio: bio);
    currentUser = updated;
    final token = ApiClient.instance.token;
    if (token != null) await TokenStorage.instance.save(token, updated);
    notifyListeners();
  }

  Future<void> uploadAvatar(String path) async {
    final updated = await UserService().uploadAvatar(path);
    currentUser = updated;
    final token = ApiClient.instance.token;
    if (token != null) await TokenStorage.instance.save(token, updated);
    notifyListeners();
  }

  Future<void> deleteAvatar() async {
    final updated = await UserService().deleteAvatar();
    currentUser = updated;
    final token = ApiClient.instance.token;
    if (token != null) await TokenStorage.instance.save(token, updated);
    notifyListeners();
  }
}
