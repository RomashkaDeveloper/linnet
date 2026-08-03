import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<ChatListProvider>().load());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showChatOptions(ChatOut chat, String currentUserId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось удалить чат: $e')));
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
                        Text('Не удалось загрузить чаты\n${chatList.error}', textAlign: TextAlign.center),
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
                      Icon(Icons.chat_bubble_outline_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
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
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final chat = filtered[index];
                    return ChatListTile(
                      chat: chat,
                      currentUserId: currentUserId,
                      onTap: () async {
                        await Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)));
                        if (mounted) context.read<ChatListProvider>().refreshChat(chat.id);
                      },
                      onLongPress: () => _showChatOptions(chat, currentUserId),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final chat = await Navigator.of(context).push<ChatOut>(
            MaterialPageRoute(builder: (_) => const NewChatScreen()),
          );
          if (chat != null && mounted) {
            context.read<ChatListProvider>().upsertChat(chat);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(chatId: chat.id)));
          }
        },
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}
