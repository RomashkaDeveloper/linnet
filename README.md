# Linnet — Flutter-клиент мессенджера

Полная реализация клиента под все эндпоинты из `docs.md` / `api.json`:
регистрация и вход, профиль и аватар, поиск пользователей, личные и групповые
чаты, отправка текста/фото/видео/файлов, редактирование и удаление сообщений,
статусы "в сети"/"печатает"/"прочитано" через WebSocket, push-регистрация.

## Куда положить файлы

1. Содержимое папки `lib/` целиком заменяет (или дополняет) папку `lib/` в
   вашем Flutter-проекте.
2. `AndroidManifest.xml` — замените им
   `android/app/src/main/AndroidManifest.xml` (в него добавлены разрешения на
   интернет, камеру, медиатеку и push, плюс `usesCleartextTraffic="true"`,
   без которого Android блокирует обычный http:// к вашему серверу для
   разработки).

## Зависимости (добавить в pubspec.yaml)

В секцию `dependencies:` добавьте:

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  http: ^1.2.2
  http_parser: ^4.0.2
  mime: ^1.0.5
  shared_preferences: ^2.3.2
  web_socket_channel: ^2.4.5
  image_picker: ^1.1.2
  file_picker: ^8.1.2
  cached_network_image: ^3.4.1
  url_launcher: ^6.3.1
```

Затем выполните:

```bash
flutter pub get
```

## Настройка адреса сервера

По умолчанию приложение обращается к `http://10.0.2.2:8000` — это адрес,
по которому Android-эмулятор видит `localhost` хост-машины, где обычно
запущен ваш backend в разработке.

- Для **Android-эмулятора**: ничего менять не нужно, если сервер запущен
  локально на порту 8000.
- Для **реального устройства**: откройте профиль → значок шестерёнки
  («Настройки сервера») и укажите LAN-адрес машины с сервером, например
  `http://192.168.1.50:8000`.
- Настройка сохраняется локально (SharedPreferences) и используется как для
  REST-запросов, так и для WebSocket-соединения (`/ws?token=...`).

## Что важно знать про Push-уведомления

`docs.md` описывает push через Firebase Cloud Messaging — сервер сам решает,
слать ли push, когда получатель офлайн. Полноценная интеграция FCM требует
отдельного шага: создание проекта в Firebase Console, добавление
`google-services.json` в `android/app/`, подключение плагина
`firebase_messaging` и настройка Gradle. Это заведомо выходит за рамки
файлов в `lib/`, поэтому в `push_service.dart` реализована рабочая, но
временная схема: генерируется и сохраняется локальный токен устройства,
который регистрируется/снимается через `/push/register` и
`/push/unregister` — так эндпоинты полностью протестированы и работают,
просто без реальной доставки через FCM. Когда подключите Firebase, замените
в `push_service.dart` генерацию локального токена на
`FirebaseMessaging.instance.getToken()` — остальной код менять не придётся.

## Медиа: фото/видео/файлы

Отправка фото и видео идёт через `image_picker` (камера или галерея), файлы —
через `file_picker`. Входящие фото показываются прямо в чате; видео, аудио и
файлы отображаются карточкой с именем и размером — по тапу открываются во
внешнем приложении устройства через `url_launcher` (полноценный video/audio
плеер внутри чата не подключался, чтобы не тащить лишние нативные
зависимости — при необходимости легко добавить `video_player`/`just_audio`
поверх уже готовой карточки в `widgets/message_bubble.dart`).

## Структура

```
lib/
  models/       — User, Chat, Message, AuthToken (парсинг JSON 1-в-1 под api.json)
  services/     — ApiClient (http-обёртка), AuthService, UserService,
                  ChatService, MessageService, PushService, SocketService,
                  ApiConfig (адрес сервера), TokenStorage (сохранение сессии)
  providers/    — AuthProvider, ChatListProvider, ChatDetailProvider
                  (state management на Provider, ChangeNotifier)
  screens/      — все экраны приложения
  widgets/      — переиспользуемые виджеты (аватар, пузырь сообщения, строка чата)
  utils/        — форматирование дат/размеров файлов
```
