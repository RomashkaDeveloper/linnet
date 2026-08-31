import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import '../providers/auth_provider.dart';
import '../providers/chat_list_provider.dart';
import '../models/chat.dart';
import '../widgets/avatar_widget.dart';
import '../widgets/chat_list_tile.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  String? _latestVersion;
  String? _downloadUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatListProvider>().load();
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Проверяет последнюю версию релизов на GitHub
  Future<void> _checkForUpdates() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version.trim();

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/RomashkaDeveloper/linnet/releases/latest'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tag = (data['tag_name'] as String? ?? '').replaceAll('v', '').trim();

        if (tag.isNotEmpty && _isNewerVersion(currentVersion, tag)) {
          if (!mounted) return;
          setState(() {
            _latestVersion = tag;
            _downloadUrl =
                'https://github.com/RomashkaDeveloper/linnet/releases/download/$tag/linnet-$tag.apk';
          });
        }
      }
    } catch (_) {
      // Игнорируем ошибки сети при проверке обновлений
    }
  }

  /// Простая проверка версии (например, 1.0.7 > 1.0.6)
  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final latestParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < latestParts.length; i++) {
      final curr = i < currentParts.length ? currentParts[i] : 0;
      if (latestParts[i] > curr) return true;
      if (latestParts[i] < curr) return false;
    }
    return false;
  }

  /// Открытие ссылки для скачивания APK
  Future<void> _downloadUpdate() async {
    if (_downloadUrl == null) return;
    final uri = Uri.parse(_downloadUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showChatOptions(ChatOut chat, String currentUserId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Удалить чат', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteChat(chat, currentUserId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteChat(ChatOut chat, String currentUserId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить чат?'),
        content: Text(
          chat.type == ChatType.group
              ? 'Вы покинете группу «${chat.displayName(currentUserId)}» и она исчезнет из списка чатов.'
              : 'Переписка с ${chat.displayName(currentUserId)} исчезнет из вашего списка чатов.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await context.read<ChatListProvider>().deleteChat(chat.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить чат: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chatList = context.watch<ChatListProvider>();
    final currentUserId = auth.currentUser?.id ?? '';

    final filtered = chatList.chats.where((c) {
      if (_query.isEmpty) return true;
      return c.displayName(currentUserId).toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Linnet', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          // Кнопка обновления (отображается только при наличии новой версии)
          if (_latestVersion != null)
            IconButton(
              icon: const Icon(Icons.download_for_offline_rounded, color: Colors.greenAccent),
              tooltip: 'Обновить до $_latestVersion',
              onPressed: _downloadUpdate,
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 4),
            child: GestureDetector(
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: AvatarWidget(
                name: auth.currentUser?.displayName ?? '?',
                imageUrl: auth.currentUser?.avatarUrl,
                size: 36,
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ChatListProvider>().load(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Поиск по чатам',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            if (chatList.isLoading && chatList.chats.isEmpty)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (chatList.error != null && chatList.chats.isEmpty)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Не удалось загрузить чаты\n${chatList.error}',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => context.read<ChatListProvider>().load(),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 56, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      const Text('Пока нет чатов'),
                      const SizedBox(height: 4),
                      const Text('Нажмите +, чтобы начать общение'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final chat = filtered[index];
                    return ChatListTile(
                      chat: chat,
                      currentUserId: currentUserId,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)),
                        );
                        if (mounted) {
                          context.read<ChatListProvider>().markRead(chat.id);
                        }
                      },
                      onLongPress: () => _showChatOptions(chat, currentUserId),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton(
          onPressed: () async {
            final chat = await Navigator.of(context).push<ChatOut>(
              MaterialPageRoute(builder: (_) => const NewChatScreen()),
            );
            if (chat != null && mounted) {
              context.read<ChatListProvider>().upsertChat(chat);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)));
            }
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}