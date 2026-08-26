import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import '../providers/auth_provider.dart';
import '../providers/call_provider.dart';
import '../providers/chat_detail_provider.dart';
import '../providers/chat_list_provider.dart';
import '../models/call.dart';
import '../models/message.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/message_bubble.dart';
import '../widgets/pending_upload_bubble.dart';
import '../utils/formatters.dart';
import 'call_screen.dart';
import 'chat_info_screen.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late final ChatDetailProvider _provider;
  ChatListProvider? _chatListProvider;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  ChatOut? _chat;
  MessageOut? _replyTo;
  MessageOut? _editing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatListProvider>().setActiveChat(widget.chatId);
      }
    });
    WidgetsBinding.instance.addObserver(this);

    _provider = ChatDetailProvider(widget.chatId);
    _provider.load().then((_) {
      if (mounted) _jumpToBottom();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatListProvider?.setActiveChat(widget.chatId);
    });

    // 1. Прокрутка вниз при получении новых сообщений от собеседника
    _provider.addListener(_onProviderUpdated);

    _loadChat();

    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels <= 80) {
        _provider.loadMore();
      }
    });

    // 2. Прокрутка вниз при открытии клавиатуры на iOS и Android
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _scrollToBottom();
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Переменную с контекстом запоминаем до того, как виджет будет уничтожен
    _chatListProvider = context.read<ChatListProvider>();
  }

  void _onProviderUpdated() {
    if (!mounted) return;
    _scrollToBottom();
  }

  // 5. Обработка включения/разблокировки экрана (resumed state)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _provider.load().then((_) {
        if (mounted) _scrollToBottom();
      });
      _loadChat();
    }
  }

  /// Instantly positions the list at the newest message — used when the
  /// chat first opens, so the user isn't dropped at the oldest message.
  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _loadChat() async {
    try {
      final chat = await ChatService().getChat(widget.chatId);
      if (mounted) setState(() => _chat = chat);
      await ChatService().markRead(widget.chatId);
      if (mounted) context.read<ChatListProvider>().markRead(widget.chatId);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.removeListener(_onProviderUpdated);
    _chatListProvider?.setActiveChat(null);
    _provider.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 3. Убираем фокус с клавиатуры перед просмотром медиафайлов
  void _unfocus() {
    _focusNode.unfocus();
    FocusScope.of(context).unfocus();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final replyId = _replyTo?.id;
    final editing = _editing;
    setState(() {
      _replyTo = null;
      _editing = null;
    });
    try {
      if (editing != null) {
        await _provider.editMessage(editing.id, text);
      } else {
        await _provider.sendText(text, replyToId: replyId);
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
    }
  }

  Future<void> _initiateCall(CallType type) async {
    _unfocus();
    final chat = _chat;
    final auth = context.read<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final otherUser = chat?.otherUser(currentUserId);
    if (chat == null || otherUser == null) return;
    try {
      await context.read<CallProvider>().startCall(chat.id, type, otherUser);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallScreen(), fullscreenDialog: true));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось начать звонок: $e')));
      }
    }
  }

  bool get _isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _sendFromPath(String? path) async {
    if (path == null) return;
    try {
      await _provider.sendMedia(path);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка отправки файла: $e')));
      }
    }
  }

  Future<void> _pickFromCamera() async {
    _unfocus();
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    await _sendFromPath(file?.path);
  }

  Future<void> _pickImageFromGallery() async {
    _unfocus();
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    await _sendFromPath(file?.path);
  }

  Future<void> _pickVideoFromGallery() async {
    _unfocus();
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    await _sendFromPath(file?.path);
  }

  Future<void> _pickAnyFile() async {
    _unfocus();
    final file = await file_selector.openFile();
    await _sendFromPath(file?.path);
  }

  void _showAttachmentSheet() {
    _unfocus();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            if (_isMobile)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Камера'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
            if (_isMobile)
              ListTile(
                leading: const Icon(Icons.photo_outlined),
                title: const Text('Фото из галереи'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromGallery();
                },
              ),
            if (_isMobile)
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Видео'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideoFromGallery();
                },
              ),
            ListTile(
              leading: const Icon(Icons.attach_file_outlined),
              title: Text(_isMobile ? 'Файл' : 'Выбрать файл (фото, видео, документ)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAnyFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onMessageLongPress(MessageOut msg, bool isMine) {
    _unfocus();
    if (msg.isDeleted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('Ответить'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyTo = msg);
              },
            ),
            if (isMine && msg.messageType == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _editing = msg;
                    _textCtrl.text = msg.content ?? '';
                  });
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _provider.deleteMessage(msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final currentUserId = auth.currentUser?.id ?? '';
    final chat = _chat;
    final otherUser = chat?.otherUser(currentUserId);

    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          actions: [
            if (chat?.type == ChatType.private && otherUser != null) ...[
              IconButton(
                icon: const Icon(Icons.call_outlined),
                tooltip: 'Аудиозвонок',
                onPressed: () => _initiateCall(CallType.audio),
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                tooltip: 'Видеозвонок',
                onPressed: () => _initiateCall(CallType.video),
              ),
            ],
          ],
          title: InkWell(
            onTap: () {
              _unfocus();
              if (chat == null) return;
              if (chat.type == ChatType.group) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatInfoScreen(chatId: chat.id)));
              } else if (otherUser != null) {
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => UserProfileScreen(userId: otherUser.id)));
              }
            },
            child: Row(
              children: [
                Consumer<ChatDetailProvider>(
                  builder: (context, p, _) => AvatarWidget(
                    name: chat?.displayName(currentUserId) ?? '',
                    imageUrl: chat?.type == ChatType.group ? chat?.avatarUrl : otherUser?.avatarUrl,
                    size: 38,
                    showOnlineDot: otherUser != null && p.isUserOnline(otherUser),
                    enableViewer: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        chat?.displayName(currentUserId) ?? '…',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Consumer<ChatDetailProvider>(builder: (context, p, _) {
                        String subtitle = '';
                        if (p.typingUserIds.isNotEmpty) {
                          subtitle = 'печатает…';
                        } else if (chat?.type == ChatType.private && otherUser != null) {
                          subtitle = p.isUserOnline(otherUser) ? 'в сети' : formatLastSeen(p.lastSeenFor(otherUser));
                        } else if (chat?.type == ChatType.group) {
                          subtitle = '${chat!.members.length} участников';
                        }
                        return Text(
                          subtitle,
                          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: Consumer<ChatDetailProvider>(
                builder: (context, p, _) {
                  if (p.isLoading && p.messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (p.error != null && p.messages.isEmpty) {
                    return Center(child: Text('Ошибка загрузки: ${p.error}'));
                  }
                  if (p.messages.isEmpty && p.pendingUploads.isEmpty) {
                    return const Center(
                      child: Text('Сообщений пока нет.\nНачните разговор!', textAlign: TextAlign.center),
                    );
                  }
                  final loadingOffset = p.isLoadingMore ? 1 : 0;
                  final totalCount = loadingOffset + p.messages.length + p.pendingUploads.length;
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: totalCount,
                    itemBuilder: (context, index) {
                      if (p.isLoadingMore && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final i = index - loadingOffset;
                      if (i >= p.messages.length) {
                        final pending = p.pendingUploads[i - p.messages.length];
                        return PendingUploadBubble(
                          pending: pending,
                          onRetry: () => _provider.retryUpload(pending),
                          onDismiss: () => _provider.dismissUpload(pending),
                        );
                      }
                      final msg = p.messages[i];
                      final isMine = msg.senderId == currentUserId;
                      MessageOut? reply;
                      if (msg.replyToId != null) {
                        for (final m in p.messages) {
                          if (m.id == msg.replyToId) {
                            reply = m;
                            break;
                          }
                        }
                      }
                      return MessageBubble(
                        message: msg,
                        isMine: isMine,
                        showSender: chat?.type == ChatType.group && !isMine,
                        replyMessage: reply,
                        onLongPress: () => _onMessageLongPress(msg, isMine),
                      );
                    },
                  );
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.4))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_replyTo != null || _editing != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(_editing != null ? Icons.edit_outlined : Icons.reply_outlined, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _editing != null ? 'Редактирование сообщения' : 'Ответ: ${_replyTo!.content ?? "медиа"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _replyTo = null;
                        _editing = null;
                        _textCtrl.clear();
                      }),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _showAttachmentSheet),
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send, // 4. Замена переноса строки на кнопку отправки
                    onSubmitted: (_) => _send(), // 4. Отправка по кнопке с клавиатуры
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (value) {
                      _provider.notifyTyping();
                      if (!_isMobile &&
                          value.endsWith('\n') &&
                          !HardwareKeyboard.instance.isShiftPressed) {
                        _textCtrl.value = TextEditingValue(
                          text: value.substring(0, value.length - 1),
                          selection: TextSelection.collapsed(offset: value.length - 1),
                        );
                        _send();
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Сообщение',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(22))),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(icon: const Icon(Icons.send_rounded), onPressed: _send),
              ],
            ),
          ],
        ),
      ),
    );
  }
}