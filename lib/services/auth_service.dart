import '../models/token.dart';
import 'api_client.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  Future<AuthToken> register({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    final data = await ApiClient.instance.post('/auth/register', body: {
      'username': username,
      'email': email,
      'password': password,
      if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
    });
    return AuthToken.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthToken> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final data = await ApiClient.instance.post('/auth/login', body: {
      'username_or_email': usernameOrEmail,
      'password': password,
    });
    return AuthToken.fromJson(data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    await ApiClient.instance.post('/auth/logout');
  }
}
