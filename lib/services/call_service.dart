import '../models/call.dart';
import 'api_client.dart';

class CallService {
  Future<List<Map<String, dynamic>>> iceServers() async {
    final data = await ApiClient.instance.get('/calls/ice-servers');
    if (data is Map && data['ice_servers'] is List) {
      return (data['ice_servers'] as List).cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<CallOut> start(String chatId, CallType type) async {
    final data = await ApiClient.instance.post('/calls/$chatId/start', body: {
      'call_type': type == CallType.video ? 'video' : 'audio',
    });
    return CallOut.fromJson(data as Map<String, dynamic>);
  }

  Future<CallOut> get(String callId) async {
    final data = await ApiClient.instance.get('/calls/$callId');
    return CallOut.fromJson(data as Map<String, dynamic>);
  }

  Future<CallOut> answer(String callId) async {
    final data = await ApiClient.instance.post('/calls/$callId/answer');
    return CallOut.fromJson(data as Map<String, dynamic>);
  }

  Future<void> reject(String callId) async {
    // Бэкенд возвращает status 204 (No Content)
    await ApiClient.instance.post('/calls/$callId/reject');
  }

  Future<CallOut> end(String callId) async {
    final data = await ApiClient.instance.post('/calls/$callId/end');
    return CallOut.fromJson(data as Map<String, dynamic>);
  }

  Future<List<CallOut>> history() async {
    final data = await ApiClient.instance.get('/calls');
    return (data as List<dynamic>)
        .map((e) => CallOut.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}