import '../models/message.dart';

/// Represents a media message currently being uploaded. Not part of the
/// API — purely local UI state so the chat can show a progress bubble
/// instead of the user staring at a frozen input bar.
class PendingUpload {
  final String localId;
  final String path;
  final MessageType type;
  double progress; // 0.0 .. 1.0
  String? error;

  PendingUpload({
    required this.localId,
    required this.path,
    required this.type,
  })  : progress = 0,
        error = null;
}

MessageType guessMessageTypeFromPath(String path) {
  final ext = path.split('.').last.toLowerCase();
  const imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'};
  const videoExts = {'mp4', 'mov', 'mkv', 'avi', 'webm', 'm4v'};
  const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'ogg', 'flac'};
  if (imageExts.contains(ext)) return MessageType.photo;
  if (videoExts.contains(ext)) return MessageType.video;
  if (audioExts.contains(ext)) return MessageType.audio;
  return MessageType.file;
}
