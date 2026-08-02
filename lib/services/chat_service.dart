import '../models/chat.dart';
import 'api_client.dart';

class ChatService {
  Future<ChatOut> createPrivate(String userId) async {
    final data = await ApiClient.instance.post('/chats/private', body: {'user_id': userId});
    return ChatOut.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatOut> createGroup(String name, List<String> memberIds) async {
    final data = await ApiClient.instance.post('/chats/group', body: {
      'name': name,
      'member_ids': memberIds,
    });
    return ChatOut.fromJson(data as Map<String, dynamic>);
  }

  Future<List<ChatOut>> listChats() async {
    final data = await ApiClient.instance.get('/chats');
    return (data as List<dynamic>)
        .map((e) => ChatOut.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ChatOut> getChat(String id) async {
    final data = await ApiClient.instance.get('/chats/$id');
    return ChatOut.fromJson(data as Map<String, dynamic>);
  }

  Future<ChatOut> addMember(String chatId, String userId) async {
    final data = await ApiClient.instance.post('/chats/$chatId/members/$userId');
    return ChatOut.fromJson(data as Map<String, dynamic>);
  }

  Future<void> leaveChat(String chatId) async {
    await ApiClient.instance.delete('/chats/$chatId/leave');
  }

  Future<void> markRead(String chatId) async {
    await ApiClient.instance.put('/chats/$chatId/read');
  }
}
