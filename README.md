# Linnet — Flutter-клиент мессенджера

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
