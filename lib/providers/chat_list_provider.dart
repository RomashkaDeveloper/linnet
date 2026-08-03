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
        _handlePresence(event);
        break;
    }
  }

  void _handlePresence(Map<String, dynamic> event) {
    final userId = event['user_id'] as String?;
    final isOnline = event['is_online'] as bool?;
    if (userId == null || isOnline == null) return;
    bool changed = false;
    for (var i = 0; i < chats.length; i++) {
      final chat = chats[i];
      final memberIdx = chat.members.indexWhere((m) => m.user.id == userId);
      if (memberIdx == -1) continue;
      final oldMember = chat.members[memberIdx];
      final updatedUser = oldMember.user.copyWith(
        isOnline: isOnline,
        // Пока не в сети — фиксируем момент, когда получили это событие,
        // как приблизительное время последнего захода.
        lastSeen: isOnline ? oldMember.user.lastSeen : DateTime.now(),
      );
      final updatedMembers = List<ChatMemberOut>.from(chat.members);
      updatedMembers[memberIdx] = ChatMemberOut(
        user: updatedUser,
        role: oldMember.role,
        joinedAt: oldMember.joinedAt,
      );
      chats[i] = chat.copyWith(members: updatedMembers);
      changed = true;
    }
    if (changed) notifyListeners();
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

  /// Removes a chat from the user's list. The API only exposes
  /// `/chats/{id}/leave` (no dedicated "delete" endpoint), so deleting a
  /// chat here means leaving it — for a private chat that just removes it
  /// from your own list; for a group it also removes you as a member.
  Future<void> deleteChat(String chatId) async {
    final idx = chats.indexWhere((c) => c.id == chatId);
    if (idx == -1) return;
    final removed = chats[idx];
    chats.removeAt(idx);
    notifyListeners();
    try {
      await _service.leaveChat(chatId);
    } catch (e) {
      // Не удалось на сервере — возвращаем чат обратно в список.
      chats.insert(idx, removed);
      _sortChats();
      notifyListeners();
      rethrow;
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
