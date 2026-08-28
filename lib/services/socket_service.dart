import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_config.dart';

/// Manages the single `/ws?token=<JWT>` connection described in docs.md.
///
/// Server -> client events forwarded on [events]: new_message,
/// message_edited, message_deleted, typing, read_receipt, presence.
/// Client -> server: typing, read, ping (see [sendTyping], [sendRead]).
///
/// Ключевая проблема, которую решает pong-таймаут ниже: после долгого сна
/// с выключенным экраном мобильная ОС может заморозить или тихо оборвать
/// TCP-сокет без того, чтобы поверх WebSocket пришёл onDone/onError —
/// sink.add() на таком "зомби"-соединении не бросает ошибку, поэтому без
/// этой проверки код мог висеть в иллюзии открытого соединения сколько
/// угодно. Теперь при каждом ping ждём ответный pong; если он не пришёл
/// вовремя, считаем соединение мёртвым и сами инициируем reconnect, даже
/// если приложение всё это время оставалось "resumed" на переднем плане.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _pingTimer;
  Timer? _pongTimeoutTimer;
  Timer? _reconnectTimer;
  String? _token;
  bool _manuallyClosed = false;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _controller.stream;

  void connect(String token) {
    _token = token;
    _manuallyClosed = false;
    _open();
  }

  void _open() {
    if (_token == null) return;
    try {
      final uri = Uri.parse('${ApiConfig.instance.wsUrl}?token=$_token');
      _channel = WebSocketChannel.connect(uri);
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              if (decoded['type'] == 'pong') {
                _pongTimeoutTimer?.cancel();
                return;
              }
              _controller.add(decoded);
            }
          } catch (_) {
            // игнорируем не-JSON фреймы
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        send({'type': 'ping'});
        _pongTimeoutTimer?.cancel();
        _pongTimeoutTimer = Timer(const Duration(seconds: 10), () {
          // Pong не пришёл — соединение мертво, но onDone/onError мог и не
          // сработать сам. Форсируем реконнект.
          _forceReconnect();
        });
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_manuallyClosed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      if (!_manuallyClosed && _token != null) _open();
    });
  }

  /// Закрывает текущий (возможно уже мёртвый) канал без выставления
  /// _manuallyClosed и сразу пробует открыть новый — в отличие от
  /// disconnect(), это не помечает разрыв как намеренный, поэтому если
  /// новое соединение тоже упадёт, обычный _scheduleReconnect продолжит
  /// попытки как обычно.
  void _forceReconnect() {
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    if (_token != null) _open();
  }

  /// Публичный метод для вызова из UI (например, из
  /// didChangeAppLifecycleState при реальном возврате из фона), когда
  /// нужно гарантированно иметь живое соединение прямо сейчас, а не
  /// ждать пока естественный ping/pong-цикл обнаружит проблему.
  void reconnect() {
    if (_token == null) return;
    _manuallyClosed = false;
    _forceReconnect();
  }

  void send(Map<String, dynamic> payload) {
    try {
      _channel?.sink.add(jsonEncode(payload));
    } catch (_) {}
  }

  void sendTyping(String chatId) => send({'type': 'typing', 'chat_id': chatId});

  void sendRead(String chatId, String messageId) =>
      send({'type': 'read', 'chat_id': chatId, 'message_id': messageId});

  void disconnect() {
    _manuallyClosed = true;
    _pingTimer?.cancel();
    _pongTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _token = null;
  }
}
