import 'package:flutter/material.dart';
import '../models/message.dart';
import '../models/pending_upload.dart';

class PendingUploadBubble extends StatelessWidget {
  final PendingUpload pending;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const PendingUploadBubble({
    super.key,
    required this.pending,
    required this.onRetry,
    required this.onDismiss,
  });

  IconData get _icon {
    switch (pending.type) {
      case MessageType.photo:
        return Icons.image_outlined;
      case MessageType.video:
        return Icons.videocam_outlined;
      case MessageType.audio:
        return Icons.mic_outlined;
      case MessageType.file:
        return Icons.insert_drive_file_outlined;
      case MessageType.text:
        return Icons.insert_drive_file_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = pending.error != null;
    final fileName = pending.path.split(RegExp(r'[\\/]+')).last;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: hasError
              ? colorScheme.errorContainer
              : colorScheme.primary.withOpacity(0.85),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: hasError
                  ? Icon(Icons.error_outline, color: colorScheme.onErrorContainer)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: pending.progress > 0 ? pending.progress : null,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                        Icon(_icon, size: 14, color: Colors.white),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasError ? colorScheme.onErrorContainer : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hasError ? 'Не удалось отправить' : 'Отправка… ${(pending.progress * 100).round()}%',
                    style: TextStyle(
                      color: (hasError ? colorScheme.onErrorContainer : Colors.white).withOpacity(0.85),
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            if (hasError) ...[
              IconButton(
                icon: Icon(Icons.refresh, color: colorScheme.onErrorContainer, size: 20),
                tooltip: 'Повторить',
                onPressed: onRetry,
              ),
              IconButton(
                icon: Icon(Icons.close, color: colorScheme.onErrorContainer, size: 20),
                tooltip: 'Убрать',
                onPressed: onDismiss,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
