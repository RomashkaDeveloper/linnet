## REST API

### Аутентификация

| Метод | Путь | Описание |
|---|---|---|
| POST | `/auth/register` | Регистрация (username, email, password, full_name) |
| POST | `/auth/login` | Вход (username_or_email, password) → JWT-токен |
| POST | `/auth/logout` | Выход (обновляет статус "не в сети") |

Токен передаётся в заголовке: `Authorization: Bearer <token>`.

### Пользователи и профиль

| Метод | Путь | Описание |
|---|---|---|
| GET | `/users/me` | Данные текущего пользователя |
| PATCH | `/users/me` | Обновить имя/описание профиля |
| POST | `/users/me/avatar` | Загрузить фото профиля (multipart `file`) |
| DELETE | `/users/me/avatar` | Удалить фото профиля |
| GET | `/users/search?query=` | Поиск пользователей по имени |
| GET | `/users/{user_id}` | Публичный профиль пользователя |

### Чаты

| Метод | Путь | Описание |
|---|---|---|
| POST | `/chats/private` | Создать/получить личный чат с пользователем (`user_id`) |
| POST | `/chats/group` | Создать групповой чат (`name`, `member_ids`) |
| GET | `/chats` | Список чатов пользователя (с последним сообщением и unread_count) |
| GET | `/chats/{chat_id}` | Данные конкретного чата |
| POST | `/chats/{chat_id}/members/{user_id}` | Добавить участника в групповой чат |
| DELETE | `/chats/{chat_id}/leave` | Покинуть чат |
| PUT | `/chats/{chat_id}/read` | Отметить чат прочитанным |

### Сообщения

| Метод | Путь | Описание |
|---|---|---|
| GET | `/chats/{chat_id}/messages?limit=&before=` | История сообщений (пагинация) |
| POST | `/chats/{chat_id}/messages` | Отправить текстовое сообщение |
| POST | `/chats/{chat_id}/messages/media` | Отправить фото/видео/аудио/файл (multipart `file`, тип определяется по расширению) |
| PATCH | `/chats/{chat_id}/messages/{message_id}` | Редактировать текстовое сообщение |
| DELETE | `/chats/{chat_id}/messages/{message_id}` | Удалить сообщение (мягкое удаление) |

Загруженные файлы раздаются по пути `/media/avatars/...` и `/media/media/...`.

### Push-уведомления

| Метод | Путь | Описание |
|---|---|---|
| POST | `/push/register` | Зарегистрировать токен устройства (`token`, `platform`: android/ios/web) |
| DELETE | `/push/unregister` | Отозвать токен устройства (например, при выходе из аккаунта) |
| GET | `/push/status` | Проверить, включены ли push на сервере |

**Настройка Firebase Cloud Messaging:**

1. Создайте проект в [Firebase Console](https://console.firebase.google.com/).
2. Зайдите в Настройки проекта → Сервисные аккаунты → «Создать новый закрытый ключ» —
   скачается JSON-файл с учётными данными.
3. Положите его на сервер (например, `firebase-credentials.json`) и укажите путь
   в переменной окружения:
   ```bash
   export FIREBASE_CREDENTIALS_PATH=/путь/к/firebase-credentials.json
   ```
4. На клиенте (Android/iOS/Web) подключите Firebase SDK, получите токен устройства
   и отправьте его на `POST /push/register` сразу после логина.

**Как это работает:** когда кто-то отправляет сообщение, сервер рассылает событие
по WebSocket всем участникам чата, у кого сейчас открыто приложение (активное
соединение). Тем участникам, кто сейчас оффлайн (WebSocket не подключён),
дополнительно отправляется push-уведомление через FCM — так получатель узнаёт
о сообщении, даже если приложение свёрнуто или телефон заблокирован.
Если Firebase не настроен (`FIREBASE_CREDENTIALS_PATH` пуст), это место в коде
просто ничего не делает — сервер продолжает работать в обычном режиме без push.
Недействительные/просроченные токены устройств автоматически удаляются из БД
при следующей отправке.

## WebSocket (реальное время)

Подключение: `ws://localhost:8000/ws?token=<JWT>`

**Исходящие события от сервера:**
- `new_message` — новое сообщение в чате
- `message_edited` — сообщение отредактировано
- `message_deleted` — сообщение удалено
- `typing` — собеседник печатает
- `read_receipt` — сообщение прочитано
- `presence` — пользователь вошёл/вышел из сети

**Входящие события от клиента:**
```json
{ "type": "typing", "chat_id": "..." }
{ "type": "read", "chat_id": "...", "message_id": "..." }
{ "type": "ping" }
```

Отправка самих сообщений (текст/фото/видео/аудио) идёт через REST-эндпоинты
(`POST /chats/{id}/messages` и `/messages/media`) — сервер сам рассылает
событие `new_message` всем участникам чата по WebSocket после сохранения в БД.
Такой подход даёт надёжную доставку (сообщение гарантированно попадает в БД)
и одновременно мгновенное оповещение подключённых клиентов.

## Пример сценария использования

```bash
# 1. Регистрация
curl -X POST http://localhost:8000/auth/register -H "Content-Type: application/json" \
  -d '{"username":"roman","email":"roman@example.com","password":"secret123"}'

# 2. Вход
curl -X POST http://localhost:8000/auth/login -H "Content-Type: application/json" \
  -d '{"username_or_email":"roman","password":"secret123"}'

# 3. Создание чата (используйте token и user_id собеседника из ответов выше)
curl -X POST http://localhost:8000/chats/private -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" -d '{"user_id":"<USER_ID>"}'

# 4. Отправка сообщения
curl -X POST http://localhost:8000/chats/<CHAT_ID>/messages -H "Authorization: Bearer <TOKEN>" \
  -H "Content-Type: application/json" -d '{"content":"Привет!"}'

# 5. Отправка фото
curl -X POST http://localhost:8000/chats/<CHAT_ID>/messages/media -H "Authorization: Bearer <TOKEN>" \
  -F "file=@photo.jpg"
```