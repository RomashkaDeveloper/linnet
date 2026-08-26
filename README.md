# Linnet — Flutter-клиент мессенджера

## Зависимости (добавить в pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # уже было
  cupertino_icons: ^1.0.8
  http: ^1.5.0
  shared_preferences: ^2.0.0

  # состояние / сеть
  provider: ^6.1.2
  http_parser: ^4.0.2
  mime: ^1.0.5
  web_socket_channel: ^2.4.5

  # медиа: выбор файлов, изображения, кэш
  image_picker: ^1.1.2
  file_selector: ^1.0.3
  cached_network_image: ^3.4.1
  url_launcher: ^6.3.1

  # встроенные плееры
  video_player: ^2.9.2
  just_audio: ^0.9.42

  # звонки (WebRTC)
  flutter_webrtc: ^0.11.7

  # системные разрешения
  permission_handler: ^11.3.1
```

Затем:
```bash
flutter clean
flutter pub get
```

## Настройка адреса сервера

https://localhost:8000 или http://62.109.2.230

### Разрешения для звонков

`AppPermissions.ensureMicrophone()` / `ensureCamera()` запрашиваются прямо
перед звонком (в `startCall`/`acceptCall`), не заранее. Если в видео-звонке
отказали в камере — звонок не срывается, а превращается в аудио-звонок.

### iOS (если будете добавлять платформу)

В `ios/Runner/Info.plist` потребуется добавить:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Микрофон нужен для звонков</string>
<key>NSCameraUsageDescription</key>
<string>Камера нужна для видеозвонков и фото</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Доступ к галерее нужен для отправки фото и видео</string>
```
Без этого iOS убьёт приложение при попытке запросить разрешение (это
системное требование Apple, не связанное с кодом в `lib/`).

## Push-уведомления

Как и раньше: `docs.md` описывает push через Firebase Cloud Messaging, но
полноценная интеграция требует Firebase-проекта и `google-services.json`
вне `lib/`. `push_service.dart` использует рабочую заглушку — генерирует
локальный токен устройства и регистрирует его через `/push/register`, так
что сам эндпоинт полностью протестирован, просто без реальной доставки
через FCM. Уведомления теперь также запрашиваются как системное разрешение
(Android 13+) через `AppPermissions.ensureNotifications()` сразу после
входа — фоново, не блокируя UI.

## Медиа: фото/видео/аудио/файлы

- **Фото** — открываются во встроенном полноэкранном просмотрщике с зумом
  (`screens/photo_viewer_screen.dart`, `InteractiveViewer` + `Hero`-анимация
  перехода). Тот же просмотрщик используется для аватарок (передайте
  `enableViewer: true` в `AvatarWidget`, где это уместно — уже включено для
  профиля, шапки чата и информации о группе).
- **Видео** — открывается во встроенном плеере `video_player`
  (`screens/video_player_screen.dart`) со шкалой перемотки и таймером.
- **Аудио** — плеер встроен прямо в пузырь сообщения
  (`widgets/audio_message_player.dart`, на базе `just_audio`): play/pause,
  перемотка слайдером, текущее время/длительность.
- **Файлы** — по-прежнему открываются во внешнем приложении через
  `url_launcher` (для произвольных документов встроенный просмотр не
  делался — не было такой задачи).
- Отправка фото/видео с камеры/галереи — через `image_picker`, который
  **не поддерживает Windows/macOS/Linux/web**, поэтому эти кнопки скрыты на
  десктопе (`_isMobile` в `chat_screen.dart`). Универсальный выбор файла —
  через `file_selector` (работает везде, включая Windows).
- **Прогресс загрузки**: `ApiClient.multipartWithProgress` оборачивает
  `http.MultipartRequest` в кастомный `BaseRequest`, который считает байты
  по мере того, как HTTP-клиент читает их для отправки — честный прогресс,
  без дополнительных пакетов вроде `dio`. Пока файл грузится, в чате
  показывается прогресс-бабл (`widgets/pending_upload_bubble.dart`) с
  процентом; при ошибке — кнопки «Повторить»/«Убрать».

## Нижняя навигация

`screens/main_shell_screen.dart` + `widgets/floating_nav_bar.dart` — плавающая
пилюля поверх контента с 4 вкладками: Чаты, Звонки, Настройки, Профиль.
Экран настроек сервера (`server_settings_screen.dart`) больше не используется
напрямую — его заменила вкладка **Настройки** (`settings_screen.dart`),
старый файл можно удалить, если не нужен для другого.

## Отправка по Enter

На десктопе (Windows/macOS/Linux) Enter в поле ввода отправляет сообщение,
Shift+Enter — переносит строку. На мобильных платформах поведение не
менялось (Enter — перенос строки, отправка — кнопкой), так как на телефоне
нет физической клавиши Shift и это стандартный паттерн мессенджеров.
Реализовано без хрупких трюков с `Shortcuts`/`Actions` — по факту вставки
`\n` в `onChanged` строка обрезается и вызывается отправка, если Shift не
зажат (`HardwareKeyboard.instance.isShiftPressed`).

## Структура

```
lib/
  models/       — User, Chat, Message, AuthToken, Call, PendingUpload
  services/     — ApiClient (http-обёртка + прогресс загрузки), AuthService,
                  UserService, ChatService, MessageService, CallService,
                  PushService, SocketService, PermissionService,
                  ApiConfig, TokenStorage
  providers/    — AuthProvider, ChatListProvider, ChatDetailProvider,
                  CallProvider (WebRTC + сигналинг)
  screens/      — все экраны приложения, включая MainShellScreen (нижняя
                  навигация), звонки, встроенные плееры/просмотрщики
  widgets/      — аватар, пузырь сообщения, строка чата, плавающий nav bar,
                  аудиоплеер, прогресс-бабл загрузки
  utils/        — форматирование дат/размеров файлов
```
