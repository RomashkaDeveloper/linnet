import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../services/user_service.dart';
import '../services/chat_service.dart';
import '../widgets/avatar_widget.dart';
import 'create_group_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchCtrl = TextEditingController();
  List<UserPublic> _results = [];
  bool _loading = false;
  String? _error;
  Timer? _debounce;

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value.trim()));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await UserService().search(query);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startPrivateChat(UserPublic user) async {
    try {
      final chat = await ChatService().createPrivate(user.id);
      if (mounted) Navigator.of(context).pop<ChatOut>(chat);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось создать чат: $e')));
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый чат'),
        actions: [
          TextButton.icon(
            onPressed: () async {
              final chat = await Navigator.of(context)
                  .push<ChatOut>(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
              if (chat != null && mounted) Navigator.of(context).pop<ChatOut>(chat);
            },
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Группа'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onChanged,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Поиск пользователей по имени', prefixIcon: Icon(Icons.search)),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final user = _results[index];
                return ListTile(
                  leading: AvatarWidget(name: user.displayName, imageUrl: user.avatarUrl, size: 48, showOnlineDot: user.isOnline),
                  title: Text(user.displayName),
                  subtitle: Text('@${user.username}'),
                  onTap: () => _startPrivateChat(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
