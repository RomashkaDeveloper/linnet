import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/message.dart';
import '../services/api_config.dart';
import '../utils/formatters.dart';

class MessageBubble extends StatelessWidget {
  final MessageOut message;
  final bool isMine;
  final bool showSender;
  final MessageOut? replyMessage;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.showSender = false,
    this.replyMessage,
    this.onLongPress,
  });

  String? get _fullMediaUrl {
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return null;
    return ApiConfig.instance.resolveMediaUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isMine ? colorScheme.primary : colorScheme.surfaceContainerHighest;
    final textColor = isMine ? colorScheme.onPrimary : colorScheme.onSurface;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSender && message.sender != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    message.sender!.displayName,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: colorScheme.primary),
                  ),
                ),
              if (replyMessage != null) _replyPreview(textColor),
              _buildContent(context, textColor),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited && !message.isDeleted)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        'изменено',
                        style: TextStyle(fontSize: 10.5, color: textColor.withValues(alpha: 0.65), fontStyle: FontStyle.italic),
                      ),
                    ),
                  Text(formatClock(message.createdAt), style: TextStyle(fontSize: 10.5, color: textColor.withValues(alpha: 0.65))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replyPreview(Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: textColor.withValues(alpha: 0.5), width: 3)),
      ),
      child: Text(
        replyMessage!.isDeleted ? 'Сообщение удалено' : (replyMessage!.content ?? 'Медиа'),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: textColor.withValues(alpha: 0.9)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color textColor) {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block, size: 15, color: textColor.withValues(alpha: 0.6)),
          const SizedBox(width: 6),
          Text('Сообщение удалено', style: TextStyle(color: textColor.withValues(alpha: 0.6), fontStyle: FontStyle.italic)),
        ],
      );
    }
    switch (message.messageType) {
      case MessageType.text:
        return Text(message.content ?? '', style: TextStyle(color: textColor, fontSize: 15.5));
      case MessageType.photo:
        return _photoContent();
      case MessageType.video:
        return _mediaFileCard(textColor, Icons.videocam_outlined, 'Видео');
      case MessageType.audio:
        return _mediaFileCard(textColor, Icons.mic_outlined, 'Аудио');
      case MessageType.file:
        return _mediaFileCard(textColor, Icons.insert_drive_file_outlined, 'Файл');
    }
  }

  Widget _photoContent() {
    final url = _fullMediaUrl;
    if (url == null) {
      return const SizedBox(width: 220, height: 120, child: Icon(Icons.image_outlined));
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
        onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: 220,
          placeholder: (_, _) => const SizedBox(
            width: 220,
            height: 160,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          errorWidget: (_, _, _) => const SizedBox(
            width: 220,
            height: 120,
            child: Icon(Icons.broken_image_outlined),
          ),
        ),
      ),
    );
  }

  Widget _mediaFileCard(Color textColor, IconData icon, String label) {
    final url = _fullMediaUrl;
    return InkWell(
      onTap: url != null ? () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication) : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(minWidth: 180),
        decoration: BoxDecoration(color: textColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: textColor),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.mediaFilename ?? label,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (message.mediaSize != null)
                    Text(
                      formatFileSize(message.mediaSize!),
                      style: TextStyle(color: textColor.withValues(alpha: 0.75), fontSize: 11.5),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
