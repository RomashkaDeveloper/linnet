import 'message.dart';
import 'user.dart';

enum ChatType { private, group }

enum MemberRole { owner, admin, member }

ChatType chatTypeFromString(String s) => ChatType.values
    .firstWhere((e) => e.name == s, orElse: () => ChatType.private);

MemberRole memberRoleFromString(String s) => MemberRole.values
    .firstWhere((e) => e.name == s, orElse: () => MemberRole.member);

class ChatMemberOut {
  final UserPublic user;
  final MemberRole role;
  final DateTime joinedAt;

  ChatMemberOut({required this.user, required this.role, required this.joinedAt});

  factory ChatMemberOut.fromJson(Map<String, dynamic> json) => ChatMemberOut(
        user: UserPublic.fromJson(json['user'] as Map<String, dynamic>),
        role: memberRoleFromString(json['role'] as String? ?? 'member'),
        joinedAt:
            DateTime.tryParse(json['joined_at'] as String? ?? '') ??
                DateTime.now(),
      );
}

class ChatOut {
  final String id;
  final ChatType type;
  final String? name;
  final String? avatarUrl;
  final DateTime createdAt;
  final List<ChatMemberOut> members;
  final MessageOut? lastMessage;
  final int unreadCount;

  ChatOut({
    required this.id,
    required this.type,
    this.name,
    this.avatarUrl,
    required this.createdAt,
    this.members = const [],
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ChatOut.fromJson(Map<String, dynamic> json) => ChatOut(
        id: json['id'] as String,
        type: chatTypeFromString(json['type'] as String? ?? 'private'),
        name: json['name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
        members: (json['members'] as List<dynamic>? ?? [])
            .map((e) => ChatMemberOut.fromJson(e as Map<String, dynamic>))
            .toList(),
        lastMessage: json['last_message'] != null
            ? MessageOut.fromJson(json['last_message'] as Map<String, dynamic>)
            : null,
        unreadCount: json['unread_count'] as int? ?? 0,
      );

  ChatOut copyWith({
    MessageOut? lastMessage,
    int? unreadCount,
    List<ChatMemberOut>? members,
  }) =>
      ChatOut(
        id: id,
        type: type,
        name: name,
        avatarUrl: avatarUrl,
        createdAt: createdAt,
        members: members ?? this.members,
        lastMessage: lastMessage ?? this.lastMessage,
        unreadCount: unreadCount ?? this.unreadCount,
      );

  /// Display name relative to the currently logged in user: for private
  /// chats shows the other participant's name, for groups shows group name.
  String displayName(String currentUserId) {
    if (type == ChatType.group) {
      return (name != null && name!.isNotEmpty) ? name! : 'Группа';
    }
    final other = otherUser(currentUserId);
    return other?.displayName ?? (name ?? 'Чат');
  }

  UserPublic? otherUser(String currentUserId) {
    if (type != ChatType.private) return null;
    for (final m in members) {
      if (m.user.id != currentUserId) return m.user;
    }
    return members.isNotEmpty ? members.first.user : null;
  }
}
