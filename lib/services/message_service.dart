import '../models/message.dart';
import 'api_client.dart';

class MessageService {
  Future<List<MessageOut>> listMessages(
    String chatId, {
    int limit = 50,
    String? before,
  }) async {
    final data = await ApiClient.instance.get('/chats/$chatId/messages', query: {
      'limit': limit,
      'before': ?before,
    });
    return (data as List<dynamic>)
        .map((e) => MessageOut.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MessageOut> sendText(String chatId, String content, {String? replyToId}) async {
    final data = await ApiClient.instance.post('/chats/$chatId/messages', body: {
      'content': content,
      'reply_to_id': ?replyToId,
    });
    return MessageOut.fromJson(data as Map<String, dynamic>);
  }

  Future<MessageOut> sendMedia(String chatId, String filePath) async {
    final data = await ApiClient.instance.multipart(
      '/chats/$chatId/messages/media',
      fieldName: 'file',
      filePath: filePath,
    );
    return MessageOut.fromJson(data as Map<String, dynamic>);
  }

  Future<MessageOut> editMessage(String chatId, String messageId, String content) async {
    final data = await ApiClient.instance
        .patch('/chats/$chatId/messages/$messageId', body: {'content': content});
    return MessageOut.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await ApiClient.instance.delete('/chats/$chatId/messages/$messageId');
  }
}
