import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// Top-level функция — ОБЯЗАТЕЛЬНО вне класса и с этим прагма-аннотацией.
/// Android запускает background-хендлер FCM в отдельном изоляте, у которого
/// нет доступа к состоянию текущего запущенного приложения (в том числе к
/// SocketService, провайдерам и т.д.) — поэтому здесь можно только
/// синхронно показать нотификацию через flutter_local_notifications, но
/// нельзя, например, дёрнуть CallProvider или переподключить сокет.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushService._showFromMessage(message);
}

// Handles the /push/* endpoints, а также приём и показ push-уведомлений
// (входящие звонки и новые сообщения), пришедших через FCM, пока
// WebSocket-соединение не восстановлено или приложение полностью убито.
class PushService {
  static const _tokenKey = 'push_device_token';

  static const _callChannelId = 'calls';
  static const _messageChannelId = 'messages';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  String get _platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'web';
  }

  /// Вызывать один раз при старте приложения (см. main.dart), ДО
  /// FirebaseMessaging.onBackgroundMessage — регистрирует Android-каналы
  /// нотификаций и слушателей foreground/tap-событий.
  ///
  /// Вся эта логика (звонки, полноэкранные уведомления) специфична для
  /// Android — на других платформах (например Windows при разработке в
  /// dev-режиме) flutter_local_notifications требует свои собственные
  /// settings для инициализации и просто не нужен для этой функциональности,
  /// поэтому выходим сразу, не трогая плагин вовсе.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    if (!Platform.isAndroid) return;

    const androidCallChannel = AndroidNotificationChannel(
      _callChannelId,
      'Входящие звонки',
      description: 'Уведомления о входящих звонках',
      importance: Importance.max,
      playSound: true,
      // Полноэкранный intent нужен именно для звонков — обычная
      // notification-плашка не разбудит экран так, как звонилка.
    );
    const androidMessageChannel = AndroidNotificationChannel(
      _messageChannelId,
      'Сообщения',
      description: 'Новые сообщения в чатах',
      importance: Importance.high,
    );

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidCallChannel);
    await androidPlugin?.createNotificationChannel(androidMessageChannel);

    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Foreground: приложение открыто — FCM не показывает системные
    // уведомления сам, поэтому решаем сами что показать. Для звонков (чистый
    // data-payload) — полноэкранное call-уведомление. Для сообщений
    // (notification+data payload) — обычное, с текстом из notification-блока.
    FirebaseMessaging.onMessage.listen((message) {
      if (message.data['type'] == 'incoming_call') {
        _showFromMessage(message);
      } else {
        _showMessageNotificationForeground(message);
      }
    });

    // Пользователь тапнул по системному уведомлению, приложение было в
    // фоне (не убито).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedFromMessage);

    // Если приложение было полностью закрыто и запущено тапом по пушу.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleOpenedFromMessage(initialMessage);
    }
  }

  static Future<void> _showFromMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String?;

    if (type == 'incoming_call') {
      // Звонки всегда идут чистым data-payload (см. send_call_push на
      // бэкенде) — система никогда не покажет их сама, показываем всегда,
      // и в foreground, и в background.
      await _showIncomingCallNotification(data);
      return;
    }
    // Обычные сообщения (send_push на бэкенде) идут С notification-блоком.
    // В фоне/killed Android покажет системное уведомление сам — рисовать
    // его вручную здесь означало бы показать пользователю два одинаковых
    // уведомления на одно сообщение. Ручной показ нужен только в
    // foreground, где FCM ничего сам не показывает — см. _showFromMessage
    // вызывается из FirebaseMessaging.onMessage для этого случая, а из
    // background handler'а для type == 'new_message' сюда доходить не
    // должен (background handler вызывает этот метод только для звонков).
  }

  /// Отдельный путь для foreground: показываем уведомление о сообщении
  /// сами, беря title/body из notification-блока, который прислал сервер,
  /// а не переизобретаем текст из data.
  static Future<void> _showMessageNotificationForeground(
      RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _localNotifications.show(
      id: message.data['message_id'].hashCode,
      title: notification.title ?? 'Новое сообщение',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _messageChannelId,
          'Сообщения',
          channelDescription: 'Новые сообщения в чатах',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: 'chat:${message.data['chat_id']}',
    );
  }

  static Future<void> _showIncomingCallNotification(
      Map<String, dynamic> data) async {
    final callerName = data['caller_name'] as String? ?? 'Входящий звонок';
    final callType = data['call_type'] as String? ?? 'audio';

    await _localNotifications.show(
      // Фиксированный id — новый входящий звонок должен заменить
      // предыдущее call-уведомление, а не копиться поверх него.
      id: 1001,
      title: callType == 'video' ? 'Видеозвонок' : 'Аудиозвонок',
      body: callerName,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _callChannelId,
          'Входящие звонки',
          channelDescription: 'Уведомления о входящих звонках',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          ongoing: true,
          autoCancel: false,
          // Требует permission.USE_FULL_SCREEN_INTENT в AndroidManifest.xml
          // и (Android 14+) чтобы пользователь разрешил это приложению в
          // настройках — иначе система тихо покажет обычное уведомление
          // вместо полноэкранного вызова.
        ),
      ),
      payload: 'call:${data['call_id']}',
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    _routeFromPayload(response.payload);
  }

  static void _handleOpenedFromMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    if (type == 'incoming_call') {
      _routeFromPayload('call:${data['call_id']}');
    } else if (type == 'new_message') {
      _routeFromPayload('chat:${data['chat_id']}');
    }
  }

  /// Навигация по тапу на уведомление живёт вне PushService — здесь нужен
  /// доступ к NavigatorKey/роутеру приложения, которого у этого сервиса
  /// нет и не должно быть. Прокинь сюда колбэк из main.dart (например,
  /// через глобальный navigatorKey), если нужна реальная навигация в чат
  /// или на экран звонка по тапу.
  static void Function(String route)? onNotificationRoute;

  static void _routeFromPayload(String? payload) {
    if (payload == null) return;
    onNotificationRoute?.call(payload);
  }

  Future<void> register() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await ApiClient.instance.post('/push/register', body: {
        'token': token,
        'platform': _platform,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (_) {
      // Push регистрация не критична для работы мессенджера — молча игнорируем.
    }
  }

  static bool _tokenRefreshSubscribed = false;

  /// FCM время от времени сам обновляет токен устройства (например, после
  /// переустановки или смены Google Play Services) — без этой подписки
  /// сервер продолжит слать push на уже недействительный токен, и уведомления
  /// (включая звонки) молча перестанут доходить без единой ошибки на клиенте.
  ///
  /// Статический флаг нужен, потому что вызывается из AuthProvider как при
  /// restore(), так и при каждом login — без защиты повторные вызовы за
  /// время жизни приложения создавали бы дублирующиеся подписки на
  /// onTokenRefresh (каждая слала бы свой /push/register при обновлении
  /// токена).
  void listenTokenRefresh() {
    if (_tokenRefreshSubscribed) return;
    _tokenRefreshSubscribed = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      try {
        await ApiClient.instance.post('/push/register', body: {
          'token': token,
          'platform': _platform,
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, token);
      } catch (_) {}
    });
  }

  Future<void> unregister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token == null) return;
      await ApiClient.instance.delete('/push/unregister', body: {'token': token});
    } catch (_) {}
  }

  Future<bool> status() async {
    try {
      final data = await ApiClient.instance.get('/push/status');
      if (data is Map && data['enabled'] is bool) return data['enabled'] as bool;
      if (data is bool) return data;
      return false;
    } catch (_) {
      return false;
    }
  }
}
