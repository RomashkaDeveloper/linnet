import 'user.dart';

class AuthToken {
  final String accessToken;
  final String tokenType;
  final UserPublic user;

  AuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) => AuthToken(
        accessToken: json['access_token'] as String,
        tokenType: json['token_type'] as String? ?? 'bearer',
        user: UserPublic.fromJson(json['user'] as Map<String, dynamic>),
      );
}
