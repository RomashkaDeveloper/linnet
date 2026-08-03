import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_selector/file_selector.dart' as file_selector;
import '../providers/auth_provider.dart';
import '../providers/chat_detail_provider.dart';
import '../providers/chat_list_provider.dart';
import '../models/message.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/message_bubble.dart';
import '../utils/formatters.dart';
import 'chat_info_screen.dart';
import 'user_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatDetailProvider _provider;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  ChatOut? _chat;
  MessageOut? _replyTo;
  MessageOut? _editing;

  @override
  void initState() {
    super.initState();
    _provider = ChatDetailProvider(widget.chatId);
    _provider.load().then((_) {
      if (mounted) _jumpToBottom();
    });
    _loadChat();
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients && _scrollCtrl.position.pixels <= 80) {
        _provider.loadMore();
      }
    });
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
    _provider.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
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

  /// image_picker only has native camera/gallery pickers on Android/iOS —
  /// on Windows/macOS/Linux/web those source options simply aren't
  /// available, so we hide them there and only offer the generic file
  /// picker (which also works fine for picking images on desktop).
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
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
    await _sendFromPath(file?.path);
  }

  Future<void> _pickImageFromGallery() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    await _sendFromPath(file?.path);
  }

  Future<void> _pickVideoFromGallery() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    await _sendFromPath(file?.path);
  }

  /// Generic "any file" picker — works on every platform including Windows,
  /// unlike image_picker's camera/gallery sources.
  Future<void> _pickAnyFile() async {
    final file = await file_selector.openFile();
    await _sendFromPath(file?.path);
  }

  void _showAttachmentSheet() {
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
          title: InkWell(
            onTap: () {
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
                  if (p.messages.isEmpty) {
                    return const Center(
                      child: Text('Сообщений пока нет.\nНачните разговор!', textAlign: TextAlign.center),
                    );
                  }
                  return ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: p.messages.length + (p.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (p.isLoadingMore && index == 0) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final i = p.isLoadingMore ? index - 1 : index;
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
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => _provider.notifyTyping(),
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
