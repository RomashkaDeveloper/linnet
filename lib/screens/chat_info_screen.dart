import 'package:flutter/material.dart';
import '../models/chat.dart';
import '../models/user.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import '../widgets/avatar_widget.dart';
import 'home_screen.dart';

class ChatInfoScreen extends StatefulWidget {
  final String chatId;
  const ChatInfoScreen({super.key, required this.chatId});

  @override
  State<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends State<ChatInfoScreen> {
  ChatOut? _chat;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final chat = await ChatService().getChat(widget.chatId);
      if (mounted) {
        setState(() {
          _chat = chat;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();
    List<UserPublic> results = [];
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: 'Поиск пользователей', prefixIcon: Icon(Icons.search)),
                  onChanged: (v) async {
                    if (v.trim().isEmpty) {
                      setSheetState(() => results = []);
                      return;
                    }
                    try {
                      final r = await UserService().search(v.trim());
                      setSheetState(() => results = r);
                    } catch (_) {}
                  },
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (ctx, i) {
                      final u = results[i];
                      return ListTile(
                        leading: AvatarWidget(name: u.displayName, imageUrl: u.avatarUrl, size: 42),
                        title: Text(u.displayName),
                        subtitle: Text('@${u.username}'),
                        onTap: () async {
                          Navigator.pop(ctx);
                          try {
                            await ChatService().addMember(widget.chatId, u.id);
                            _load();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(content: Text('Не удалось добавить: $e')));
                            }
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _leave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Покинуть группу?'),
        content: const Text('Вы перестанете получать сообщения из этого чата.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Покинуть', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ChatService().leaveChat(widget.chatId);
        if (mounted) {
          Navigator.of(context)
              .pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (r) => false);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = _chat;
    return Scaffold(
      appBar: AppBar(title: const Text('Информация о группе')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : chat == null
              ? const Center(child: Text('Не удалось загрузить'))
              : ListView(
                  children: [
                    const SizedBox(height: 16),
                    Center(child: AvatarWidget(name: chat.name ?? '?', imageUrl: chat.avatarUrl, size: 96, enableViewer: true)),
                    const SizedBox(height: 12),
                    Text(
                      chat.name ?? 'Группа',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${chat.members.length} участников',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.person_add_alt_outlined),
                      title: const Text('Добавить участника'),
                      onTap: _addMember,
                    ),
                    const Divider(),
                    ...chat.members.map((m) => ListTile(
                          leading: AvatarWidget(
                            name: m.user.displayName,
                            imageUrl: m.user.avatarUrl,
                            size: 44,
                            showOnlineDot: m.user.isOnline,
                          ),
                          title: Text(m.user.displayName),
                          subtitle: Text(
                            m.role == MemberRole.owner
                                ? 'Владелец'
                                : m.role == MemberRole.admin
                                    ? 'Администратор'
                                    : 'Участник',
                          ),
                        )),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.exit_to_app, color: Colors.red),
                      title: const Text('Покинуть группу', style: TextStyle(color: Colors.red)),
                      onTap: _leave,
                    ),
                  ],
                ),
    );
  }
}
