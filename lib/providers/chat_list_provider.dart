import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/chat.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';

class ChatListProvider extends ChangeNotifier {
  final ChatService _service = ChatService();
  StreamSubscription? _sub;

  List<ChatOut> chats = [];
  bool isLoading = false;
  String? error;

  ChatListProvider() {
    _sub = SocketService.instance.events.listen(_onEvent);
  }

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();
    try {
      chats = await _service.listChats();
      _sortChats();
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _sortChats() {
    chats.sort((a, b) {
      final at = a.lastMessage?.createdAt ?? a.createdAt;
      final bt = b.lastMessage?.createdAt ?? b.createdAt;
      return bt.compareTo(at);
    });
  }

  void _onEvent(Map<String, dynamic> event) {
    final type = event['type'];
    switch (type) {
      case 'new_message':
        _handleNewMessage(event);
        break;
      case 'read_receipt':
      case 'message_edited':
      case 'message_deleted':
        final chatId = event['chat_id'] as String?;
        if (chatId != null) refreshChat(chatId);
        break;
      case 'presence':
        // Пересобираем список, чтобы виджеты, слушающие chats, перерисовались
        // с новым статусом "в сети" (сам статус хранится в объекте User,
        // поэтому полноценно обновляется при следующей загрузке/refreshChat).
        notifyListeners();
        break;
    }
  }

  void _handleNewMessage(Map<String, dynamic> event) {
    final chatId = event['chat_id'] as String?;
    if (chatId == null) return;
    final idx = chats.indexWhere((c) => c.id == chatId);
    try {
      final raw = event['message'] ?? event;
      final msg = MessageOut.fromJson(raw as Map<String, dynamic>);
      if (idx != -1) {
        chats[idx] = chats[idx].copyWith(
          lastMessage: msg,
          unreadCount: chats[idx].unreadCount + 1,
        );
        _sortChats();
        notifyListeners();
      } else {
        refreshChat(chatId);
      }
    } catch (_) {
      refreshChat(chatId);
    }
  }

  Future<void> refreshChat(String chatId) async {
    try {
      final chat = await _service.getChat(chatId);
      final idx = chats.indexWhere((c) => c.id == chatId);
      if (idx != -1) {
        chats[idx] = chat;
      } else {
        chats.insert(0, chat);
      }
      _sortChats();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(String chatId) async {
    final idx = chats.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      chats[idx] = chats[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  void upsertChat(ChatOut chat) {
    final idx = chats.indexWhere((c) => c.id == chat.id);
    if (idx != -1) {
      chats[idx] = chat;
    } else {
      chats.insert(0, chat);
    }
    _sortChats();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
