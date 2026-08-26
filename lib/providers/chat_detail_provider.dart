import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../models/pending_upload.dart';
import '../models/user.dart';
import '../services/message_service.dart';
import '../services/socket_service.dart';

class ChatDetailProvider extends ChangeNotifier {
  final String chatId;
  final MessageService _service = MessageService();
  StreamSubscription? _sub;
  Timer? _typingClearTimer;

  List<MessageOut> messages = [];
  bool isLoading = false;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? error;
  final Set<String> typingUserIds = {};

  /// Media messages currently uploading — shown as progress bubbles at the
  /// bottom of the chat until the upload finishes (success removes them,
  /// failure keeps them with an error + retry/dismiss option).
  final List<PendingUpload> pendingUploads = [];

  ChatDetailProvider(this.chatId) {
    _sub = SocketService.instance.events.listen(_onEvent);
  }

  void _sortAscending() {
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      final list = await _service.listMessages(chatId, limit: 50);
      messages = list;
      _sortAscending();
      hasMore = list.length >= 50;
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore || messages.isEmpty) return;
    isLoadingMore = true;
    notifyListeners();
    try {
      // messages is kept sorted ascending, so the oldest loaded message is
      // always at index 0 — use its timestamp as the "before" cursor to
      // fetch the next older page.
      final oldest = messages.first;
      final more = await _service.listMessages(
        chatId,
        limit: 50,
        before: oldest.createdAt.toIso8601String(),
      );
      if (more.isEmpty) {
        hasMore = false;
      } else {
        for (final m in more) {
          if (!messages.any((existing) => existing.id == m.id)) {
            messages.add(m);
          }
        }
        _sortAscending();
        hasMore = more.length >= 50;
      }
    } catch (_) {
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> sendText(String content, {String? replyToId}) async {
    final msg = await _service.sendText(chatId, content, replyToId: replyToId);
    if (!messages.any((m) => m.id == msg.id)) {
      messages.add(msg);
      notifyListeners();
    }
  }

  // Future<void> sendMedia(String path) async {
  //   final pending = PendingUpload(
  //     localId: '${DateTime.now().microsecondsSinceEpoch}',
  //     path: path,
  //     type: guessMessageTypeFromPath(path),
  //   );
  //   pendingUploads.add(pending);
  //   notifyListeners();
  //   await _upload(pending);
  // }

  Future<void> retryUpload(PendingUpload pending) async {
    pending.error = null;
    pending.progress = 0;
    notifyListeners();
    await _upload(pending);
  }

  void dismissUpload(PendingUpload pending) {
    pendingUploads.remove(pending);
    notifyListeners();
  }

  Future<void> _upload(PendingUpload pending) async {
    try {
      final msg = await _service.sendMediaWithProgress(
        chatId,
        pending.path,
        onProgress: (sent, total) {
          pending.progress = total > 0 ? sent / total : 0;
          notifyListeners();
        },
      );
      pendingUploads.remove(pending);
      if (!messages.any((m) => m.id == msg.id)) {
        messages.add(msg);
      }
      notifyListeners();
    } catch (e) {
      pending.error = e.toString();
      notifyListeners();
    }
  }

  Future<void> sendMedia(String path) async {
    final msg = await _service.sendMedia(chatId, path);
    if (!messages.any((m) => m.id == msg.id)) {
      messages.add(msg);
      notifyListeners();
    }
  }

  Future<void> editMessage(String messageId, String content) async {
    final updated = await _service.editMessage(chatId, messageId, content);
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      messages[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> deleteMessage(String messageId) async {
    await _service.deleteMessage(chatId, messageId);
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      messages[idx] = messages[idx].copyWith(isDeleted: true, content: null);
      notifyListeners();
    }
  }

  void notifyTyping() => SocketService.instance.sendTyping(chatId);

  void notifyRead(String messageId) => SocketService.instance.sendRead(chatId, messageId);

  void _onEvent(Map<String, dynamic> event) {
    // presence — это событие про пользователя в целом, а не про конкретный
    // чат, поэтому оно не содержит chat_id и должно обрабатываться до
    // фильтра ниже (иначе оно просто отбрасывалось бы).
    if (event['type'] == 'presence') {
      _handlePresence(event);
      return;
    }
    final eventChatId = event['chat_id'] as String?;
    if (eventChatId != chatId) return;
    switch (event['type']) {
      case 'new_message':
        _handleIncoming(event);
        break;
      case 'message_edited':
        _handleEdited(event);
        break;
      case 'message_deleted':
        _handleDeleted(event);
        break;
      case 'typing':
        _handleTyping(event);
        break;
      case 'read_receipt':
        notifyListeners();
        break;
    }
  }

  /// user_id -> live online status received over the socket, overriding
  /// whatever was true at the moment the chat/user was first fetched.
  final Map<String, bool> onlineOverrides = {};
  final Map<String, DateTime> lastSeenOverrides = {};

  bool isUserOnline(UserPublic user) => onlineOverrides[user.id] ?? user.isOnline;

  DateTime lastSeenFor(UserPublic user) => lastSeenOverrides[user.id] ?? user.lastSeen;

  void _handlePresence(Map<String, dynamic> event) {
    final userId = event['user_id'] as String?;
    final isOnline = event['is_online'] as bool?;
    if (userId == null || isOnline == null) return;
    onlineOverrides[userId] = isOnline;
    if (!isOnline) {
      lastSeenOverrides[userId] = DateTime.now();
    }
    notifyListeners();
  }

  void _handleIncoming(Map<String, dynamic> event) {
    try {
      final raw = event['message'] ?? event;
      final msg = MessageOut.fromJson(raw as Map<String, dynamic>);
      if (!messages.any((m) => m.id == msg.id)) {
        messages.add(msg);
        notifyListeners();
      }
    } catch (_) {}
  }

  void _handleEdited(Map<String, dynamic> event) {
    try {
      final raw = event['message'] ?? event;
      final msg = MessageOut.fromJson(raw as Map<String, dynamic>);
      final idx = messages.indexWhere((m) => m.id == msg.id);
      if (idx != -1) {
        messages[idx] = msg;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _handleDeleted(Map<String, dynamic> event) {
    final messageId = event['message_id'] as String?;
    if (messageId == null) return;
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      messages[idx] = messages[idx].copyWith(isDeleted: true, content: null);
      notifyListeners();
    }
  }

  void _handleTyping(Map<String, dynamic> event) {
    final userId = event['user_id'] as String?;
    if (userId == null) return;
    typingUserIds.add(userId);
    notifyListeners();
    _typingClearTimer?.cancel();
    _typingClearTimer = Timer(const Duration(seconds: 3), () {
      typingUserIds.remove(userId);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _typingClearTimer?.cancel();
    super.dispose();
  }
}
