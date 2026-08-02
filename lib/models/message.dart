import 'user.dart';

enum MessageType { text, photo, video, audio, file }

MessageType messageTypeFromString(String s) => MessageType.values
    .firstWhere((e) => e.name == s, orElse: () => MessageType.text);

class MessageOut {
  final String id;
  final String chatId;
  final String senderId;
  final UserPublic? sender;
  final MessageType messageType;
  final String? content;
  final String? mediaUrl;
  final String? mediaFilename;
  final int? mediaSize;
  final int? durationSeconds;
  final String? replyToId;
  final bool isEdited;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime? editedAt;

  MessageOut({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.sender,
    required this.messageType,
    this.content,
    this.mediaUrl,
    this.mediaFilename,
    this.mediaSize,
    this.durationSeconds,
    this.replyToId,
    required this.isEdited,
    required this.isDeleted,
    required this.createdAt,
    this.editedAt,
  });

  factory MessageOut.fromJson(Map<String, dynamic> json) => MessageOut(
        id: json['id'] as String,
        chatId: json['chat_id'] as String,
        senderId: json['sender_id'] as String,
        sender: json['sender'] != null
            ? UserPublic.fromJson(json['sender'] as Map<String, dynamic>)
            : null,
        messageType:
            messageTypeFromString(json['message_type'] as String? ?? 'text'),
        content: json['content'] as String?,
        mediaUrl: json['media_url'] as String?,
        mediaFilename: json['media_filename'] as String?,
        mediaSize: json['media_size'] as int?,
        durationSeconds: json['duration_seconds'] as int?,
        replyToId: json['reply_to_id'] as String?,
        isEdited: json['is_edited'] as bool? ?? false,
        isDeleted: json['is_deleted'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
        editedAt: json['edited_at'] != null
            ? DateTime.tryParse(json['edited_at'] as String)
            : null,
      );

  MessageOut copyWith({
    bool? isDeleted,
    String? content,
    bool? isEdited,
    DateTime? editedAt,
  }) =>
      MessageOut(
        id: id,
        chatId: chatId,
        senderId: senderId,
        sender: sender,
        messageType: messageType,
        content: content ?? this.content,
        mediaUrl: mediaUrl,
        mediaFilename: mediaFilename,
        mediaSize: mediaSize,
        durationSeconds: durationSeconds,
        replyToId: replyToId,
        isEdited: isEdited ?? this.isEdited,
        isDeleted: isDeleted ?? this.isDeleted,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
      );
}
