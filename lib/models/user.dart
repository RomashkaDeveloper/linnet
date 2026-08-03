class UserPublic {
  final String id;
  final String username;
  final String? fullName;
  final String? bio;
  final String? avatarUrl;
  final bool isOnline;
  final DateTime lastSeen;

  UserPublic({
    required this.id,
    required this.username,
    this.fullName,
    this.bio,
    this.avatarUrl,
    required this.isOnline,
    required this.lastSeen,
  });

  factory UserPublic.fromJson(Map<String, dynamic> json) => UserPublic(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['full_name'] as String?,
        bio: json['bio'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isOnline: json['is_online'] as bool? ?? false,
        lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? '') ?? DateTime.now(),
      );

  String get displayName =>
      (fullName != null && fullName!.trim().isNotEmpty) ? fullName! : username;

  UserPublic copyWith({bool? isOnline, DateTime? lastSeen}) => UserPublic(
        id: id,
        username: username,
        fullName: fullName,
        bio: bio,
        avatarUrl: avatarUrl,
        isOnline: isOnline ?? this.isOnline,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

class UserPrivate extends UserPublic {
  final String email;
  final DateTime createdAt;

  UserPrivate({
    required super.id,
    required super.username,
    super.fullName,
    super.bio,
    super.avatarUrl,
    required super.isOnline,
    required super.lastSeen,
    required this.email,
    required this.createdAt,
  });

  factory UserPrivate.fromJson(Map<String, dynamic> json) => UserPrivate(
        id: json['id'] as String,
        username: json['username'] as String,
        fullName: json['full_name'] as String?,
        bio: json['bio'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isOnline: json['is_online'] as bool? ?? false,
        lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? '') ?? DateTime.now(),
        email: json['email'] as String,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}
