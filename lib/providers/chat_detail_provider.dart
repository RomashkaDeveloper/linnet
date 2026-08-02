import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
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

  ChatDetailProvider(this.chatId) {
    _sub = SocketService.instance.events.listen(_onEvent);
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      // Сервер отдаёт последние сообщения первыми — разворачиваем для
      // отображения от старых к новым, как в обычном чате.
      final list = await _service.listMessages(chatId, limit: 50);
      messages = list.reversed.toList();
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
      final oldest = messages.first;
      final more = await _service.listMessages(
        chatId,
        limit: 50,
        before: oldest.createdAt.toIso8601String(),
      );
      if (more.isEmpty) {
        hasMore = false;
      } else {
        messages.insertAll(0, more.reversed);
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
