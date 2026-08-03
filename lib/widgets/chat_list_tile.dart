import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../utils/formatters.dart';
import 'avatar_widget.dart';

class ChatListTile extends StatelessWidget {
  final ChatOut chat;
  final String currentUserId;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ChatListTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
    this.onLongPress,
  });

  String _preview() {
    final lastMessage = chat.lastMessage;
    if (lastMessage == null) return 'Нет сообщений';
    String body;
    if (lastMessage.isDeleted) {
      body = 'Сообщение удалено';
    } else {
      switch (lastMessage.messageType) {
        case MessageType.text:
          body = lastMessage.content ?? '';
          break;
        case MessageType.photo:
          body = '📷 Фото';
          break;
        case MessageType.video:
          body = '🎬 Видео';
          break;
        case MessageType.audio:
          body = '🎵 Аудио';
          break;
        case MessageType.file:
          body = '📎 ${lastMessage.mediaFilename ?? "Файл"}';
          break;
      }
    }
    if (lastMessage.senderId == currentUserId) return 'Вы: $body';
    return body;
  }

  @override
  Widget build(BuildContext context) {
    final other = chat.otherUser(currentUserId);
    final lastMessage = chat.lastMessage;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AvatarWidget(
        name: chat.displayName(currentUserId),
        imageUrl: chat.type == ChatType.group ? chat.avatarUrl : other?.avatarUrl,
        size: 52,
        showOnlineDot: chat.type == ChatType.private && (other?.isOnline ?? false),
      ),
      title: Text(
        chat.displayName(currentUserId),
        style: const TextStyle(fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _preview(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            lastMessage != null ? formatChatTimestamp(lastMessage.createdAt) : '',
            style: TextStyle(
              fontSize: 12,
              color: chat.unreadCount > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
              fontWeight: chat.unreadCount > 0 ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
          const SizedBox(height: 6),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${chat.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}
